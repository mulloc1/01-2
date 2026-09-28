# 평가 문항 3 · Deadlock

`MEMORY_LIMIT=512`, `CPU_MAX_OCCUPY=10`으로 고정하고 `MULTI_THREAD_ENABLE`만 변경했습니다.

Before에서 Thread-1은 `Shared_Memory_A`를 획득한 뒤 `Socket_Pool_B`를 기다렸고, Thread-2는 `Socket_Pool_B`를 획득한 뒤 `Shared_Memory_A`를 기다렸습니다. 두 스레드가 모두 `Status: BLOCKED`가 된 2026-09-28 16:45:24 이후 로그 진행이 멈췄지만 실험 수집기는 관찰 시간이 끝날 때까지 프로세스가 살아 있는 것으로 확인했습니다.

After에서는 멀티스레드를 비활성화했습니다. 스케줄러 작업이 완료된 뒤 MemoryWorker와 CpuWorker 로그가 관찰 종료까지 계속 기록되어 교착이 회피됐습니다.

- [Before 실제 로그](../../evidence/deadlock/before/app.log)
- [After 실제 로그](../../evidence/deadlock/after/app.log)
