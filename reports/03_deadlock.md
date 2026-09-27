# [Bug] Deadlock - 두 워커가 서로의 자원을 기다리며 진행 정지

## 1. Description (현상 설명)

`MEMORY_LIMIT=512`, `CPU_MAX_OCCUPY=10`으로 고정하고 `MULTI_THREAD_ENABLE=true`로 실행했다. PID 9660과 포트 15034는 48초 관찰 내내 유지됐지만, 15:08:32 이후 앱 로그가 더 이상 증가하지 않았다. 멀티스레드를 비활성화한 비교 실행에서는 스케줄러·메모리·CPU 로그가 계속 진행됐다.

## 2. Evidence & Logs (증거 자료)

Before/After 조건과 핵심 로그는 [Deadlock 증거](../evidence/deadlock.md)에 있다.

```text
[Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
[Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
[Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
[Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)
```

스레드 표본에서 PID 9660의 세 스레드는 반복해서 `futex_wait` 상태이며 CPU는 0.0~0.1%, RSS는 22,988KB로 고정됐다.

```text
2026-09-24T15:09:10+09:00 9660 9660 ... 0.0 0.2 22988 futex_wait agent-leak-app
2026-09-24T15:09:10+09:00 9660 9936 ... 0.0 0.2 22988 futex_wait agent-leak-app
2026-09-24T15:09:10+09:00 9660 9937 ... 0.0 0.2 22988 futex_wait agent-leak-app
```

47초 시점에도 PID 9660은 `0.0.0.0:15034`를 LISTEN하고 있었다. 관제 표본도 같은 PID가 살아 있으면서 CPU 0~1%, 시스템 MEM 6~7%로 정체된 상태를 기록한다.

After에서는 스케줄러 작업 완료 후 MemoryWorker와 CpuWorker 로그가 48초 동안 계속 증가한다.

## 3. Root Cause Analysis (원인 분석)

- 상호 배제: `Shared_Memory_A`와 `Socket_Pool_B`는 한 번에 한 스레드만 보유한다.
- 점유 대기: Thread-1은 A를 가진 채 B를 기다리고 Thread-2는 B를 가진 채 A를 기다린다.
- 비선점: 다른 스레드가 보유한 lock을 강제로 회수하지 못하고 `futex_wait`에 머문다.
- 순환 대기: Thread-1 → B → Thread-2 → A → Thread-1의 순환 관계가 형성된다.

네 조건이 동시에 충족되고 로그·CPU·RSS가 정지했으므로 단순 유휴나 I/O 지연이 아니라 Deadlock으로 판단한다. 근본 해결은 모든 스레드가 A→B처럼 동일한 전역 순서로 lock을 획득하게 하고, 필요하면 `try_lock`·timeout·rollback을 추가하는 것이다.

## 4. Workaround & Verification (조치 및 검증)

| 지표 | Before | After |
|---|---:|---:|
| `MULTI_THREAD_ENABLE` | true | false |
| 나머지 조건 | 512MB, CPU 10% | 512MB, CPU 10% |
| PID/포트 | 48초 내내 생존 | 48초 내내 생존 |
| 마지막 진행 | 15:08:32 BLOCKED | 관찰 종료까지 계속 진행 |
| 워커 상태 | `futex_wait`, CPU 0% | Memory/CPU 로그 지속 |
| Deadlock | 재현 | 회피 |

멀티스레드 비활성화는 동시성 자체를 제거하는 임시 회피책이며 처리량을 희생한다. 코드 수준 해결은 일관된 lock 순서다.
