from django import template

register = template.Library()

@register.filter
def get_item(dictionary, key):
    """Get an item from a dictionary or form field by key"""
    try:
        if hasattr(dictionary, key):
            return getattr(dictionary, key)
        return dictionary.get(key)
    except:
        return None

@register.filter
def add(value, arg):
    """Add the arg to the value."""
    try:
        return str(value) + str(arg)
    except (ValueError, TypeError):
        return ''

@register.filter
def split(value, arg):
    """Split a string by the given separator"""
    return value.split(arg)