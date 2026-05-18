# CLAUDE.md

이 문서는 Claude Code(또는 다른 코딩 에이전트)가 이 레포에서 작업할 때 빠르게 맥락을 이해하도록 돕는 작업 안내서입니다.

## 이 레포가 하는 일

이 레포는 **SW-Hub 프로젝트의 인프라 코드 저장소**입니다.

현재 목표는 다음 둘을 **한 레포 안에서 분리 운영**하는 것입니다.

- `terraform/`: 인프라 프로비저닝
- `ansible/`: 서버 구성 관리

지금은 프로젝트 초반이라 **깊은 구현보다 구조를 먼저 잡는 단계**입니다.
즉, 과한 세부 구현보다 아래 원칙이 더 중요합니다.

- 구조가 명확할 것
- 환경 분리가 쉬울 것
- 나중에 클라우드/provider를 붙이기 쉬울 것
- 서버 역할이 섞이지 않을 것
- 비밀값을 코드에 박지 않을 것

## 지금 우리가 하고 있는 것

현재 이 레포에서 하고 있는 일은 다음과 같습니다.

1. SW-Hub 인프라의 **기본 디렉토리 구조**를 잡는다.
2. Terraform과 Ansible의 **책임 경계**를 나눈다.
3. dev 환경부터 시작할 수 있게 **최소 실행 단위**를 만든다.
4. 이후 실제 서버/클라우드 구성이 들어와도 크게 뜯어고치지 않도록 **확장 가능한 골조**를 만든다.

한마디로 말하면:

> 지금은 서비스 구현이 아니라, SW-Hub 인프라를 오래 굴릴 수 있게 만드는 첫 바닥 공사 단계다.

## 현재 구조

```text
terraform/
  environments/dev   # dev 엔트리포인트
  modules/network    # 네트워크 모듈 뼈대
  modules/compute    # 컴퓨트 모듈 뼈대

ansible/
  inventories/dev    # dev 인벤토리 예시
  playbooks/         # bootstrap / site
  roles/common       # 공통 기본 설정
  roles/docker       # 런타임 준비용 placeholder
```

## 서버 아키텍처 설명 (사진 기반 초기 해석)

사용자가 공유한 아키텍처 사진을 기준으로, 현재 레포는 아래와 같은 방향을 전제로 초안이 잡혀 있습니다.

### 1. 계층 분리

핵심은 **외부 진입 지점**과 **실제 애플리케이션 실행 서버**를 분리하는 것입니다.

- 외부에서 접근 가능한 진입 계층(public 성격)
- 실제 서비스가 도는 내부 계층(private 성격)

이렇게 하면 보안 경계가 선명해지고, 운영도 훨씬 편해집니다.

### 2. 관리/진입 노드 + 앱 노드 구조

현재 dev 인벤토리에는 아래 placeholder가 들어 있습니다.

- `bastion` 1대
- `app` 노드 2대

이건 실제 확정 아키텍처라기보다,
**“관리 또는 진입용 노드 1개 + 내부 앱 서버 여러 대”** 라는 패턴을 먼저 반영한 것입니다.

### 3. 네트워크 분리 전제

Terraform 쪽은 아래처럼 확장하기 쉬운 형태로 잡아두었습니다.

- VPC CIDR
- public subnet CIDRs
- private subnet CIDRs

즉, 현재 골조는
**public 쪽에는 진입점/관리 포인트를 두고, private 쪽에는 앱 서버를 배치하는 방향**에 맞춰져 있습니다.

### 4. 이후 확장될 수 있는 계층

사진 기준으로 봤을 때, 이후 자연스럽게 붙을 수 있는 계층은 다음과 같습니다.

- reverse proxy / load balancer
- application service nodes
- database
- cache / queue
- monitoring / logging
- CI/CD runner 또는 배포 제어 지점

하지만 지금은 이걸 다 박아넣지 않고,
**Terraform module / Ansible role로 확장 가능한 상태만 먼저 만든다**가 원칙입니다.

## 작업 원칙

이 레포에서 작업할 때는 아래를 지켜주세요.

### 1. 너무 깊게 구현하지 말 것

사용자 요청상 현재 단계는 **기초 공사**입니다.
실제 provider 리소스, 서비스별 role, 배포 자동화까지 한 번에 깊게 들어가지 마세요.

우선순위:
- 구조
- 명명
- 분리
- 확장성

### 2. Terraform과 Ansible 역할을 섞지 말 것

- Terraform: 자원 생성/선언
- Ansible: 생성된 서버 설정/구성

예를 들어:
- 서버를 몇 대 만들지 = Terraform
- 서버에 Docker를 설치할지 = Ansible

### 3. 환경별 분리를 염두에 둘 것

지금은 `dev`만 있지만, 앞으로 `stage`, `prod`가 추가될 가능성이 큽니다.
따라서 새 파일/디렉토리를 만들 때는 환경 확장이 쉬운지 먼저 보세요.

### 4. 비밀값은 커밋하지 말 것

다음은 절대 하드코딩하지 마세요.

- API 키
- SSH private key
- 비밀번호
- 토큰
- 실서비스 민감 endpoint 정보

필요 시 예시 파일은 `.example` 형태로 두세요.

### 5. 문서는 한국어 중심으로 유지

이 레포는 사용자가 직접 보고 관리할 가능성이 높습니다.
그래서 README 같은 핵심 문서는 **한국어 중심**이 더 좋습니다.
단, 커밋 메시지는 영어 컨벤션(`feat: ...`)을 유지합니다.

## 변경할 때 추천 순서

1. 먼저 `README.md`와 현재 구조를 읽고 의도를 파악한다.
2. 변경이 Terraform인지 Ansible인지 경계를 정한다.
3. 최소 변경으로 골조를 확장한다.
4. 가능하면 syntax/validate 수준 검증을 추가한다.
5. 문서도 같이 갱신한다.

## 좋은 변경의 예

- `terraform/modules/network`에 provider 연결을 붙이되, dev 엔트리포인트 구조는 유지
- `ansible/roles/docker`를 실제 설치 role로 확장
- `inventories/dev`를 실제 dev 서버 기준으로 정리
- GitHub Actions에 lint/validate를 조금 더 보강

## 피해야 할 변경

- provider도 안 정해졌는데 특정 클라우드 종속 구조를 너무 깊게 박기
- Ansible에 인프라 생성 책임까지 우겨넣기
- README/문서 없이 구조만 복잡하게 키우기
- secrets를 예시랍시고 실제값처럼 넣기

## 현재 다음 단계 후보

우선순위 후보는 대략 이렇습니다.

1. 실제 클라우드/provider 확정 후 Terraform provider 붙이기
2. dev inventory 실제값 반영
3. Docker / reverse proxy role 구체화
4. stage / prod 분리
5. app 배포 전략(예: compose/systemd/k8s 등) 확정

## 한 줄 요약

이 레포는 지금
**“SW-Hub 인프라의 첫 기준선을 만드는 중”** 이다.

Claude Code는 이 점을 기억하고,
과한 구현보다 **깔끔한 구조, 분리, 확장성** 쪽으로 작업해주면 된다.
