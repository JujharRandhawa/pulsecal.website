/**
 * CSRF Protection Utilities for PulseCal
 * Provides consistent CSRF token handling across the application
 */

// Get CSRF token from multiple sources (production safe)
function getCSRFToken() {
    let token = null;
    
    // Method 1: From cookie
    if (document.cookie && document.cookie !== '') {
        const cookies = document.cookie.split(';');
        for (let i = 0; i < cookies.length; i++) {
            const cookie = cookies[i].trim();
            if (cookie.substring(0, 10) === 'csrftoken=') {
                token = decodeURIComponent(cookie.substring(10));
                break;
            }
        }
    }
    
    // Method 2: From form input (fallback)
    if (!token) {
        const csrfInput = document.querySelector('[name=csrfmiddlewaretoken]');
        if (csrfInput) {
            token = csrfInput.value;
        }
    }
    
    // Method 3: From meta tag (fallback)
    if (!token) {
        const metaTag = document.querySelector('meta[name="csrf-token"]');
        if (metaTag) {
            token = metaTag.getAttribute('content');
        }
    }
    
    return token;
}

// Set up CSRF token for fetch requests (production safe)
function setupCSRFForFetch() {
    const originalFetch = window.fetch;
    window.fetch = function(url, options = {}) {
        // Check if this is a same-origin request
        const isSameOrigin = !url.startsWith('http://') && !url.startsWith('https://') || 
                           url.startsWith(window.location.origin);
        
        if (isSameOrigin) {
            options.headers = options.headers || {};
            options.credentials = options.credentials || 'same-origin';
            
            // Add CSRF token for state-changing methods
            if (options.method && ['POST', 'PUT', 'PATCH', 'DELETE'].includes(options.method.toUpperCase())) {
                const token = getCSRFToken();
                if (token) {
                    options.headers['X-CSRFToken'] = token;
                }
            }
        }
        return originalFetch(url, options);
    };
}

// Add CSRF token to forms (production safe)
function addCSRFToForms() {
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        if (form.method.toLowerCase() === 'post' && !form.querySelector('input[name="csrfmiddlewaretoken"]')) {
            const token = getCSRFToken();
            if (token) {
                const csrfInput = document.createElement('input');
                csrfInput.type = 'hidden';
                csrfInput.name = 'csrfmiddlewaretoken';
                csrfInput.value = token;
                form.appendChild(csrfInput);
            }
        }
    });
}

// Refresh CSRF token periodically (production safe)
function refreshCSRFToken() {
    fetch('/csrf-token/', {
        method: 'GET',
        credentials: 'same-origin'
    })
    .then(response => {
        if (response.ok) {
            return response.json();
        }
        throw new Error('CSRF token refresh failed');
    })
    .then(data => {
        if (data.token) {
            // Update all CSRF inputs
            const csrfInputs = document.querySelectorAll('[name=csrfmiddlewaretoken]');
            csrfInputs.forEach(input => {
                input.value = data.token;
            });
            
            // Update global token
            window.csrfToken = data.token;
        }
    })
    .catch(error => {
        console.warn('CSRF token refresh failed:', error);
    });
}

// jQuery AJAX setup (if jQuery is available)
function setupCSRFForJQuery() {
    if (typeof $ !== 'undefined') {
        $.ajaxSetup({
            beforeSend: function(xhr, settings) {
                if (!this.crossDomain && !/^(GET|HEAD|OPTIONS|TRACE)$/i.test(settings.type)) {
                    const token = getCSRFToken();
                    if (token) {
                        xhr.setRequestHeader("X-CSRFToken", token);
                    }
                }
            }
        });
    }
}

// Initialize CSRF protection
document.addEventListener('DOMContentLoaded', function() {
    setupCSRFForFetch();
    setupCSRFForJQuery();
    addCSRFToForms();
    
    // Set global CSRF token for other scripts
    window.csrfToken = getCSRFToken();
    
    // Auto-refresh CSRF token in production
    if (window.location.protocol === 'https:') {
        setInterval(refreshCSRFToken, 300000); // 5 minutes
    }
    
    // Refresh token on page visibility change
    document.addEventListener('visibilitychange', function() {
        if (!document.hidden) {
            refreshCSRFToken();
        }
    });
});

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        getCSRFToken,
        setupCSRFForFetch,
        addCSRFToForms
    };
}