# [Bug] OOM Crash - 50MB 한계에서 MemoryGuard가 프로세스를 자체 종료

## 1. Description (현상 설명)

Ubuntu ARM64 VM에서 `MEMORY_LIMIT=50`, `CPU_MAX_OCCUPY=10`, `MULTI_THREAD_ENABLE=false`로 실행하자 메모리 워커의 힙이 25MB씩 증가했고 50MB 도달 직후 프로세스가 종료됐다. 비교 실행은 메모리 한계만 512MB로 변경했다.

## 2. Evidence & Logs (증거 자료)

Before/After 조건과 핵심 로그는 [OOM 증거](../evidence/oom.md)에 있다.

```text
2026-09-24 13:01:19,953 [INFO] [MemoryWorker] Current Heap: 25MB
2026-09-24 13:01:22,978 [INFO] [MemoryWorker] Current Heap: 50MB
2026-09-24 13:01:22,978 [CRITICAL] [MemoryGuard] Memory limit exceeded (50MB >= 50MB) / (Recommend Over 256MB)
2026-09-24 13:01:22,978 [CRITICAL] [MemoryGuard] Self-terminating process 1699 to prevent system instability.
```

프로세스 RSS 표본은 PID 1699가 19,016KB에서 44,620KB로 증가한 것을 보여준다. 마지막 샘플과 종료 로그 사이에 50MB에 도달했으며 전체 관찰 시간은 7초였다. 시스템 관제에서도 같은 PID가 기록됐다.

```text
[2026-09-24 13:01:19] PID:1699 CPU:0% MEM:6% DISK_USED:2%
[2026-09-24 13:01:22] PID:1699 CPU:0% MEM:7% DISK_USED:2%
```

After에서는 힙이 25MB부터 375MB까지 계속 증가했고 최고 RSS는 406,548KB였다. 48초 관찰 종료 시점까지 MemoryGuard 종료 로그는 없었다.

## 3. Root Cause Analysis (원인 분석)

메모리 워커가 주기적으로 25MB를 할당한 뒤 해제하지 않아 RSS가 계속 증가했다. `MemoryGuard`는 설정된 한계에 도달하자 노드 전체의 메모리 고갈을 막기 위해 PID 1699를 자체 종료했다. 앱 로그가 종료 주체를 직접 명시하므로 이 결과를 Linux 커널 OOM Killer로 해석하지 않는다.

`MEMORY_LIMIT` 상향은 임계점만 이동시킨다. After에서도 RSS가 계속 상승했으므로 누수 자체는 해결되지 않았다. 근본 해결은 장기 보관되는 버퍼의 소유권과 해제 경로를 수정하고, RSS 증가율 기반 경보 및 cgroup 메모리 한계를 함께 적용하는 것이다.

## 4. Workaround & Verification (조치 및 검증)

| 지표 | Before | After |
|---|---:|---:|
| `MEMORY_LIMIT` | 50MB | 512MB |
| 나머지 조건 | CPU 10%, single-thread | CPU 10%, single-thread |
| 관찰 결과 | 7초 후 자체 종료 | 48초 관찰 동안 생존 |
| 앱 힙 마지막 값 | 50MB | 375MB |
| 관측 최고 RSS | 44,620KB | 406,548KB |
| MemoryGuard 종료 로그 | 있음 | 없음 |

한계를 512MB로 높이면 생존 시간은 늘지만 RSS 증가가 유지되므로 임시 완화책일 뿐이다.
