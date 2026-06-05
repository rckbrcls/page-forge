from __future__ import annotations


class ConvertBooksError(RuntimeError):
    """Base error for user-facing failures."""


class ConversionError(ConvertBooksError):
    """Raised when ebook conversion cannot finish."""


class ConfigurationError(ConvertBooksError):
    """Raised when the app configuration is missing or invalid."""


class DependencyError(ConvertBooksError):
    """Raised when an external dependency is missing."""
