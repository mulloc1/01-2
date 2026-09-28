# 평가 문항 6 · CPU 과점유 진단 과정

먼저 앱 로그의 `CpuWorker Current Load`로 부하가 계속 상승하는지 확인하고, 운영체제 도구로 대상 프로세스만 교차 확인합니다.

- `pgrep -x agent-leak-app`: 정확한 이름으로 PID 검색
- `top -b -n 1 -p PID`: 대화형 화면 없이 한 번만 대상 PID 상태 수집
- `ps -o pid,ppid,stat,pcpu,etimes -p PID`: PID 관계, 상태, 누적 CPU 비율과 실행 시간 확인
- `/proc/PID/stat`: 짧은 간격의 CPU tick 차이로 구간 CPU 사용량 계산

시스템 전체 CPU가 아니라 해당 PID의 값을 확인하는 것이 핵심입니다. 앱의 `Current Load`는 내부 시나리오 값이고 `top`·`ps` 값은 OS 측정값이므로 같은 수치로 해석하지 않습니다. 마지막으로 `CPU Threshold Violated`와 PID 소실을 연결해 보호 정책에 의한 종료로 판단합니다.
