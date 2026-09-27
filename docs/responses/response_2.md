# 기준 2 · CPU Latency

`CPU_MAX_OCCUPY=100`에서 앱 내부 부하가 5%에서 55.14%까지 증가했고 `CPU Threshold Violated` 직후 40초 만에 종료됐다. `/proc` 기반 0.25초 샘플의 실제 프로세스 CPU 최고치는 18.90%였다.

10% 실행은 부하가 5~10% 사이에서 cooldown을 반복하며 48초 동안 생존했고 OS 샘플 최고치는 7.57%였다. 상세 증거는 [CPU 보고서](../../reports/02_cpu.md)에 있다.

