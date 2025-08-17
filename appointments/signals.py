from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from allauth.socialaccount.signals import pre_social_login
from allauth.account.signals import user_signed_up
from .models import UserProfile

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Create UserProfile when User is created"""
    if created:
        UserProfile.objects.get_or_create(
            user=instance,
            defaults={'role': 'patient'}
        )

@receiver(post_save, sender=User)
def save_user_profile(sender, instance, **kwargs):
    """Save UserProfile when User is saved"""
    if hasattr(instance, 'profile'):
        instance.profile.save()

@receiver(user_signed_up)
def user_signed_up_handler(request, user, **kwargs):
    """Handle user signup from social accounts"""
    # Ensure profile exists
    profile, created = UserProfile.objects.get_or_create(
        user=user,
        defaults={'role': 'patient'}
    )
    
    # If user signed up via social account, get additional info
    if hasattr(user, 'socialaccount_set'):
        social_account = user.socialaccount_set.first()
        if social_account:
            extra_data = social_account.extra_data
            
            # Update profile with Google data
            if social_account.provider == 'google':
                if not user.first_name and extra_data.get('given_name'):
                    user.first_name = extra_data.get('given_name')
                if not user.last_name and extra_data.get('family_name'):
                    user.last_name = extra_data.get('family_name')
                user.save()

@receiver(pre_social_login)
def pre_social_login_handler(request, sociallogin, **kwargs):
    """Handle pre-social login to link accounts"""
    if sociallogin.account.provider == 'google':
        email = sociallogin.account.extra_data.get('email')
        if email:
            try:
                # Check if user with this email already exists
                existing_user = User.objects.get(email=email)
                if not existing_user.socialaccount_set.filter(provider='google').exists():
                    # Link the social account to existing user
                    sociallogin.connect(request, existing_user)
            except User.DoesNotExist:
                pass