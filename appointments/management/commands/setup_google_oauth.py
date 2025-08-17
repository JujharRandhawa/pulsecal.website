from django.core.management.base import BaseCommand
from django.conf import settings
from allauth.socialaccount.models import SocialApp
from django.contrib.sites.models import Site

class Command(BaseCommand):
    help = 'Set up Google OAuth configuration'

    def handle(self, *args, **options):
        # Get or create the site
        site, created = Site.objects.get_or_create(
            id=settings.SITE_ID,
            defaults={
                'domain': 'localhost:8000' if settings.DEBUG else 'pulsecal.com',
                'name': 'PulseCal'
            }
        )
        
        if created:
            self.stdout.write(
                self.style.SUCCESS(f'Created site: {site.domain}')
            )
        
        # Check if Google OAuth credentials are configured
        if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
            self.stdout.write(
                self.style.WARNING(
                    'Google OAuth credentials not found in environment variables.\n'
                    'Please set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in your .env file.'
                )
            )
            return
        
        # Create or update Google OAuth app
        google_app, created = SocialApp.objects.get_or_create(
            provider='google',
            defaults={
                'name': 'Google OAuth',
                'client_id': settings.GOOGLE_CLIENT_ID,
                'secret': settings.GOOGLE_CLIENT_SECRET,
            }
        )
        
        if not created:
            # Update existing app
            google_app.client_id = settings.GOOGLE_CLIENT_ID
            google_app.secret = settings.GOOGLE_CLIENT_SECRET
            google_app.save()
            self.stdout.write(
                self.style.SUCCESS('Updated existing Google OAuth app')
            )
        else:
            self.stdout.write(
                self.style.SUCCESS('Created new Google OAuth app')
            )
        
        # Add site to the app
        google_app.sites.add(site)
        
        self.stdout.write(
            self.style.SUCCESS(
                f'Google OAuth setup complete!\n'
                f'Client ID: {settings.GOOGLE_CLIENT_ID[:20]}...\n'
                f'Site: {site.domain}\n'
                f'Redirect URI: {settings.GOOGLE_REDIRECT_URI}'
            )
        )
        
        # Provide setup instructions
        self.stdout.write(
            self.style.WARNING(
                '\nIMPORTANT: Make sure to configure the following in Google Cloud Console:\n'
                f'1. Authorized JavaScript origins: {"http://localhost:8000" if settings.DEBUG else "https://" + site.domain}\n'
                f'2. Authorized redirect URIs: {settings.GOOGLE_REDIRECT_URI}\n'
                '3. Enable Google+ API and Google OAuth2 API\n'
            )
        )