from types import ModuleType


def get_futu_sdk() -> ModuleType | None:
    try:
        import futu
    except ImportError:
        return None
    return futu
