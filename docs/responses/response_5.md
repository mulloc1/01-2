# 기준 5 · 메모리 누수 추적 과정

1. `pgrep -x agent-leak-app`로 부모·워커 PID를 찾았다.
2. `ps -o pid,ppid,pmem,rss,vsz,etimes`를 약 3초 간격으로 저장했다.
3. `monitor.sh`로 시스템 전체 MEM%를 함께 기록했다.
4. 앱의 `MemoryWorker Current Heap`과 RSS 상승 시각을 맞췄다.
5. PID 소실 직전 `MemoryGuard` 로그로 종료 원인을 확정했다.

핵심은 시스템 MEM%만 보지 않고 대상 워커 PID의 RSS를 별도로 추적한 것이다.

