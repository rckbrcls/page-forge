from __future__ import annotations


class PageForgeError(RuntimeError):
    """Base error for user-facing failures."""


class ConversionError(PageForgeError):
    """Raised when ebook conversion cannot finish."""


class ConfigurationError(PageForgeError):
    """Raised when the app configuration is missing or invalid."""


class DependencyError(PageForgeError):
    """Raised when an external dependency is missing."""
