# Deadlock 증거

실행 환경: Ubuntu 26.04 LTS ARM64 / 일반 사용자 `agent-dev` / 포트 `15034`  
고정 조건: `MEMORY_LIMIT=512`, `CPU_MAX_OCCUPY=10`

## Before & After

| 평가 지표 | Before | After |
|---|---:|---:|
| `MULTI_THREAD_ENABLE` | true | false |
| 관찰 시간 | 48초 | 48초 |
| PID와 포트 | PID 9660, 포트 15034 유지 | 유지 |
| 로그 진행 | 15:08:32 이후 정지 | 관찰 종료까지 진행 |
| CPU/RSS | CPU 0~0.1%, RSS 22,988KB 고정 | 메모리·CPU 작업 계속 진행 |
| 스레드 상태 | 세 스레드 `futex_wait` | 교착 없음 |

## 핵심 증거

```text
# Before — lock 보유 및 순환 대기
[Worker-Thread-1] LOCK ACQUIRED: [Shared_Memory_A]. (Holding...)
[Worker-Thread-2] LOCK ACQUIRED: [Socket_Pool_B]. (Holding...)
[Worker-Thread-1] WAITING for [Socket_Pool_B]... (Status: BLOCKED)
[Worker-Thread-2] WAITING for [Shared_Memory_A]... (Status: BLOCKED)

# 48초 시점에도 PID와 포트 생존
PID=9660 TID=9660 CPU=0.0% RSS=22,988KB WCHAN=futex_wait
PID=9660 TID=9936 CPU=0.0% RSS=22,988KB WCHAN=futex_wait
PID=9660 TID=9937 CPU=0.0% RSS=22,988KB WCHAN=futex_wait
LISTEN 0.0.0.0:15034 PID=9660

# After
[Scheduler] All tasks completed.
[MemoryWorker] Current Heap 로그 지속
[CpuWorker] Current Load 로그 지속
```

## 판정

Thread-1이 A를 보유한 채 B를 기다리고 Thread-2가 B를 보유한 채 A를 기다려 순환 대기가 발생했다. PID와 포트는 살아 있지만 로그·CPU·RSS가 정체됐으며, 멀티스레드 비활성화 후 교착이 재현되지 않았다.

