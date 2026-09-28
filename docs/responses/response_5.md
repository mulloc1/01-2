# 평가 문항 5 · 메모리 누수 추적 과정

현재 `monitor.sh`는 다음 순서로 동작합니다.

1. `pgrep -n -x agent-leak-app`으로 가장 최근 대상 PID를 찾습니다.
2. `/proc/meminfo`에서 `MemTotal`과 `MemAvailable`을 `awk`로 추출합니다.
3. `(MemTotal - MemAvailable) / MemTotal × 100`으로 시스템 메모리 사용률을 계산합니다.
4. 시각, PID, CPU·메모리·디스크 사용률을 `/var/log/agent-app/monitor.log`에 기록합니다.
5. 앱 로그의 `Current Heap` 증가 시각과 `MemoryGuard` 종료 시각을 함께 비교합니다.

현재 MEM 값은 시스템 전체 비율이므로 프로세스 자체의 물리 메모리를 더 정확히 보려면 `ps -o rss= -p "$pid"` 또는 `/proc/$pid/status`의 `VmRSS`도 함께 기록해야 합니다.
