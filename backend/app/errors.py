from typing import Any

from fastapi import HTTPException, status


class ApiErrorCode:
    POSITION_NOT_FOUND = "POSITION_NOT_FOUND"
    FUTU_DEPENDENCY_MISSING = "FUTU_DEPENDENCY_MISSING"
    FUTU_UNAVAILABLE = "FUTU_UNAVAILABLE"
    FUTU_NO_DATA = "FUTU_NO_DATA"
    FUTU_PARTIAL_FAILURE = "FUTU_PARTIAL_FAILURE"


def api_error(
    status_code: int,
    code: str,
    message: str,
    detail: dict[str, Any] | None = None,
) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={
            "code": code,
            "message": message,
            "detail": detail or {},
        },
    )


def not_found_error(message: str, **detail: Any) -> HTTPException:
    return api_error(
        status.HTTP_404_NOT_FOUND,
        ApiErrorCode.POSITION_NOT_FOUND,
        message,
        detail,
    )


def futu_dependency_error(message: str) -> HTTPException:
    return api_error(
        status.HTTP_503_SERVICE_UNAVAILABLE,
        ApiErrorCode.FUTU_DEPENDENCY_MISSING,
        "futu-api 未安装，无法使用富途行情",
        {"reason": message},
    )


def futu_unavailable_error(message: str) -> HTTPException:
    return api_error(
        status.HTTP_502_BAD_GATEWAY,
        ApiErrorCode.FUTU_UNAVAILABLE,
        "FutuOpenD 不可用或富途接口调用失败",
        {"reason": message},
    )


def futu_no_data_error(message: str, **detail: Any) -> HTTPException:
    return api_error(
        status.HTTP_404_NOT_FOUND,
        ApiErrorCode.FUTU_NO_DATA,
        message,
        detail,
    )
