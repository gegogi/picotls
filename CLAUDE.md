# CLAUDE.md

이 파일은 Claude Code (claude.ai/code)가 이 저장소의 코드를 다룰 때 참고할 수 있는 가이드를 제공합니다.

## 프로젝트 개요

Picotls는 C로 작성된 TLS 1.3 (RFC 8446) 프로토콜 스택으로, 빠르고 작고 낮은 지연시간을 목표로 설계되었습니다. H2O HTTP 서버에서 HTTP/1, HTTP/2, HTTP/3 over QUIC을 위한 TLS 구현체로 사용됩니다.

## 빌드 명령어

```bash
# 서브모듈 초기화 (클론 후 필수)
git submodule init
git submodule update

# 기본 빌드
cmake .
make

# 전체 테스트 실행
make check
```

### CMake 옵션

- `-DWITH_FUSION=ON` - 최적화된 "fusion" AES-GCM 엔진 활성화 (AVX2, AES-NI, PCLMUL, VAES 필요)
- `-DWITH_AEGIS=ON` - AEGIS AEAD 활성화 (libaegis 필요)
- `-DWITH_MBEDTLS=ON` - MbedTLS 백엔드 활성화
- `-DWITH_DTRACE=ON` - USDT 프로브 활성화
- `-DBUILD_FUZZER=ON` - 퍼징 타겟 빌드 (Clang 필요)
- `-DOPENSSL_ROOT_DIR=<경로>` - 커스텀 OpenSSL 위치 지정

### Windows

Visual Studio 빌드 방법은 `WindowsPort.md`를 참조하세요. VS 솔루션은 `picotlsvs/` 디렉토리에 있습니다.

## 테스트

테스트는 `deps/picotest/`의 picotest 프레임워크를 사용합니다.

```bash
# CMake를 통한 전체 테스트 실행
make check

# prove로 직접 테스트 실행
prove --exec '' -v build/*.t t/*.t

# 개별 테스트 실행 파일 (빌드 후)
./test-openssl.t      # OpenSSL 백엔드 테스트
./test-minicrypto.t   # Minicrypto 백엔드 테스트
./test-fusion.t       # Fusion AES-GCM 테스트 (WITH_FUSION 시)
./test-mbedtls.t      # MbedTLS 테스트 (WITH_MBEDTLS 시)
```

테스트 자산(인증서, 키)은 `t/assets/`에 있습니다.

## CLI 도구

`cli` 실행 파일은 테스트용 클라이언트/서버입니다:

```bash
# 서버 시작
./cli -c /path/to/cert.pem -k /path/to/key.pem 127.0.0.1 8443

# 클라이언트로 연결
./cli 127.0.0.1 8443

# 세션 재개 사용
./cli -s session-file 127.0.0.1 8443

# 0-RTT 초기 데이터 사용
./cli -s session-file -e 127.0.0.1 8443
```

## 아키텍처

### 핵심 컴포넌트

- **`lib/picotls.c`** - 메인 TLS 1.3 프로토콜 구현 (~7200줄), 핸드셰이크 상태 머신, 레코드 레이어
- **`lib/hpke.c`** - 하이브리드 공개키 암호화 (RFC 9180)
- **`include/picotls.h`** - 모든 데이터 구조와 함수 선언이 포함된 공개 API 헤더

### 암호화 백엔드 아키텍처

라이브러리는 플러그인 방식의 암호화 백엔드 설계를 사용합니다. 각 백엔드는 함수 포인터 구조체로 정의된 알고리즘 인터페이스를 구현합니다:

| 백엔드 | 소스 | 의존성 | 용도 |
|--------|------|--------|------|
| OpenSSL | `lib/openssl.c` | libcrypto | 전체 기능, 프로덕션 |
| Minicrypto | `lib/cifra.c`, `lib/uecc.c` | cifra, micro-ecc (번들) | 최소 의존성 |
| Fusion | `lib/fusion.c` | 없음 (CPU 인트린식) | 고성능 AEAD |
| MbedTLS | `lib/mbedtls.c` | mbedtls 라이브러리 | 대체 TLS 라이브러리 |

백엔드별 헤더는 `include/picotls/`에 있습니다 (예: `openssl.h`, `minicrypto.h`).

### 주요 데이터 구조

- `ptls_t` - TLS 연결 상태
- `ptls_context_t` - 연결을 위한 설정 및 콜백
- `ptls_cipher_suite_t` - 알고리즘 조합 (AEAD 암호 + 해시)
- `ptls_buffer_t` - 전체에서 사용되는 가변 크기 바이트 버퍼
- `ptls_iovec_t` - 단순 바이트 벡터 (포인터 + 길이)

### 특수 기능

- **`lib/ffx.c`** - 형식 보존 암호화 (NIST SP 800-38G)
- **`lib/certificate_compression.c`** - RFC 8879 지원 (brotli 필요)
- **`lib/asn1.c`** - ASN.1 인코딩/디코딩 유틸리티

### 외부 의존성

`deps/`에 번들됨:
- `cifra/` - 경량 암호화 프리미티브
- `micro-ecc/` - 컴팩트 ECC 구현
- `picotest/` - 테스트 프레임워크

## 코드 규칙

- C99 표준 (`-std=c99`)
- 접두사: 공개 API는 `ptls_`, 상수/매크로는 `PTLS_`
- `_WINDOWS` 매크로와 `wincompat.h`를 통한 Windows 호환성
- `PTLS_MEMORY_DEBUG=1` 컴파일 플래그로 메모리 디버깅 가능

## 보안

취약점은 h2o-vuln@googlegroups.com으로 보고하세요 (SECURITY.md 참조).
