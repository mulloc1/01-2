# 평가 문항 7 · Deadlock 진단 과정

진단 순서는 다음과 같습니다.

1. `tail -f app.log`로 두 스레드가 `BLOCKED`된 뒤 로그가 더 이상 진행되지 않는 것을 확인합니다.
2. `pgrep -x agent-leak-app`으로 프로세스가 종료되지 않았는지 확인합니다.
3. `ss -ltnp 'sport = :15034'`로 리스닝 상태가 유지되는지 확인합니다.
4. `ps -p PID -o pid,stat,pcpu,pmem,rss,etimes`로 CPU와 RSS가 정체되는지 확인합니다.
5. `ps -L -p PID -o pid,tid,stat,pcpu,wchan,comm`으로 스레드가 `futex_wait` 같은 락 대기 상태인지 확인합니다.
6. 마지막 로그를 이용해 `Thread-1: A 보유 → B 대기`, `Thread-2: B 보유 → A 대기` 관계를 그립니다.
7. `MULTI_THREAD_ENABLE=false`로 다시 실행해 로그 진행이 회복되는지 비교합니다.

PID가 있다는 사실만으로 정상이라고 보지 않고, 진행 여부와 스레드 대기 상태까지 확인하는 것이 판단의 핵심입니다.
