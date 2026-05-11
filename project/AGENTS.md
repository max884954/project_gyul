# Agent Instructions

이 저장소의 `project` 폴더는 Godot 4 게임 프로젝트입니다. 모든 작업은 Godot의 `res://` 경로 기준과 기존 프로젝트 구조를 우선합니다.

## Project Layout

- `assets/art/characters`: 캐릭터 스프라이트, 초상화, 애니메이션 프레임
- `assets/art/environments`: 배경, 월드 오브젝트, 풍경 이미지
- `assets/art/props`: 상호작용 오브젝트, 아이템, 장식물
- `assets/art/ui`: 버튼, 아이콘, 패널, HUD 이미지
- `assets/art/effects`: 파티클 텍스처, 이펙트 스프라이트
- `assets/art/tilesets`: 타일셋 이미지와 관련 리소스
- `assets/art/source`: 원본 작업 파일, 레퍼런스, 편집 가능한 소스 파일

## Godot Guidelines

- Godot 버전은 프로젝트의 `project.godot` 설정을 기준으로 맞춥니다.
- 씬은 가능한 작고 재사용 가능한 단위로 나눕니다.
- 스크립트는 해당 씬 또는 기능과 가까운 위치에 둡니다.
- Godot에서 생성한 `.import` 파일은 에셋과 함께 유지합니다.
- `.godot/` 캐시 폴더는 직접 수정하지 않습니다.

## Asset Guidelines

- 게임에서 직접 쓰는 아트 에셋은 `assets/art` 아래 카테고리에 넣습니다.
- 원본 PSD, Aseprite, Krita, Blender 파일 등은 `assets/art/source`에 보관합니다.
- 파일명은 소문자 `snake_case`를 사용합니다. 예: `player_idle_01.png`
- 해상도, 피벗, 프레임 크기가 중요한 에셋은 같은 폴더에 짧은 메모 파일을 추가합니다.
- 불필요하게 큰 원본 파일이나 임시 내보내기 파일은 커밋하기 전에 정리합니다.

## Coding Guidelines

- GDScript는 Godot 기본 스타일을 따릅니다.
- 노드 경로 문자열은 가능하면 한 곳에서만 관리하고, 재사용되는 노드는 `@onready`로 캐싱합니다.
- 공개 변수는 에디터 조정이 필요할 때 `@export`를 사용합니다.
- 입력, 저장, 씬 전환처럼 전역 성격이 강한 기능은 오토로드 사용 여부를 먼저 검토합니다.
- 새 기능에는 최소한 에디터에서 확인 가능한 씬 또는 간단한 테스트 경로를 남깁니다.

## Collaboration Rules

- 사용자 작업물이나 기존 에셋을 임의로 덮어쓰지 않습니다.
- 큰 구조 변경 전에는 현재 구조와 Godot 리소스 참조를 확인합니다.
- 파일 이동 시 `.tscn`, `.tres`, `.gd`의 `res://` 참조가 깨지지 않는지 확인합니다.
- 생성한 에셋, 씬, 스크립트는 목적이 드러나는 이름을 붙입니다.
