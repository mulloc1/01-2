# 기준 3 · Deadlock

`MULTI_THREAD_ENABLE=true`에서 PID 9660과 포트 15034는 48초 동안 유지됐지만 로그는 15:08:32에 멈췄다. Thread-1은 `Shared_Memory_A`를 보유한 채 `Socket_Pool_B`를, Thread-2는 반대로 기다렸다. 세 스레드는 `futex_wait`, CPU 0%, RSS 22,988KB로 정체됐다.

`false` 실행에서는 스케줄러 완료 후 메모리·CPU 로그가 계속됐다. 상세 증거는 [Deadlock 보고서](../../reports/03_deadlock.md)에 있다.

