class PushProviderConfigurationError(RuntimeError):
    """Raised when a push provider is not configured for real delivery."""


class PushProviderSendError(RuntimeError):
    """Raised when a configured push provider fails while sending."""
