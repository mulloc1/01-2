# 기준 14 · 코드 수준 개선

- OOM: 처리 후 참조 해제, 크기 제한 queue, 메모리 회귀 테스트
- CPU: busy loop를 blocking wait/backoff로 변경, worker pool 제한
- Deadlock: 전역 lock 순서와 `try_lock`/timeout 적용

환경 변수 조정은 재현과 완화용이며 위 코드 변경이 근본 해결이다.

