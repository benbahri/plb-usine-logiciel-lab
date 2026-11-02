// Lab uniquement : identifiants fixes, assistant de configuration désactivé
// (JAVA_OPTS=-Djenkins.install.runSetupWizard=false). Ne jamais reproduire
// ce script en production.
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.get()
def realm = new HudsonPrivateSecurityRealm(false)
realm.createAccount('admin', 'admin1234')
instance.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
