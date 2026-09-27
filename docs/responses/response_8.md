# 기준 8 · OOM과 메모리 보호

누수를 방치하면 호스트의 `MemAvailable`이 감소하고 reclaim·swap·커널 OOM Killer로 영향이 확산될 수 있다. MemoryGuard가 설정 한계에서 자기 프로세스를 종료하면 메모리를 반환하고 장애 범위를 제한한다.

이번 로그는 종료 주체를 `MemoryGuard`라고 명시하므로 커널 OOM Killer와 구분된다. 한계 상향은 종료 시점만 늦추며 근본 해결은 메모리 소유권과 해제 경로 수정이다.

