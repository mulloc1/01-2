# 기준 12 · 장애 심각도와 예방

이번 조건에서는 Deadlock이 가장 치명적이다. OOM과 CPU 보호 종료는 PID·포트 소실로 감지되지만, Deadlock은 PID와 포트가 유지돼 단순 liveness 검사를 통과하면서 실제 요청은 멈출 수 있다.

근본 예방은 일관된 lock 순서, lock timeout, progress 기반 readiness 검사다. 다만 메모리 보호가 없는 실제 노드에서는 OOM의 영향 범위가 더 클 수 있다.

