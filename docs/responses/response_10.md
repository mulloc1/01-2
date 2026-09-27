# 기준 10 · Deadlock 원리

Thread-1은 `Shared_Memory_A`를 독점한 채 `Socket_Pool_B`를 기다리고, Thread-2는 B를 독점한 채 A를 기다렸다. 이는 상호 배제·점유 대기·비선점·순환 대기를 모두 만족한다.

로그의 보유·대기 관계와 커널 `futex_wait`가 일치하므로 Deadlock으로 판단했다. 예방 방법은 모든 경로에서 동일한 lock 획득 순서를 지키는 것이다.

