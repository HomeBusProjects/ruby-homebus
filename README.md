# ruby-homebus

Ruby language bindings for the Homebus provisioning and pubsub
protocols, as well as a wrapper for building Homebus applications and
managing their configuration.

## Homebus

This class stores top-level provisioning server information and
manages provisioning credentials. It is independent of the other
classes and does not save any state or configuration.

Either create a new Hombus object and login to verify credentials and
get a token or restore one from saved configuration.

### Homebus.new

```
homebus = Homebus.new(server: "server_url")
```

server_url is of the form `https://homebus.org` or
`http://localhost:3000`.

### Homebus.login

```
homebus.login(email_address, password)
```

attempts to login the user on the stored Homebus provisioning
server. Returns authorization token or `nil` on failure.

### Homebus.logout

__(to be implemented)__

```
homebus.logout(token)
```

invalides the given authorization token.

## Homebus::Provision

This class implements the Homebus provisioning protocol. It is
independent of the other classes and does not save any state or
configuration.

### Homebus::Provision.new

```
	provision_request = Homebus::Provision.new(name: 'pr name',
	                                           consumes: [ DDCS], 
	                                           publishes: [ DDCS], 
	                                           devices: [ Homebus::Device ],
	                                           publishes: [ DDCS], 
										       server: 'https://homebus.io',
											   token: API_TOKEN)
```
                                                 

## Homebus::App Lifecycle

```
app = Homebus.App.new
```

Loads account-wide, Homebus state, app state and app configuration.

``` 
app.setup!
```

The application's configuration and state are available to it.

The application should perform any housekeeping tasks and further
initialization. It should set up the `devices` array. For instance, if
interfacing to a cloud based service, this would be the time to read
the list of devices in the cloud service and set up the array.


```
app.work!
```

`Homebus::App` creates the Homebus::Provision object before calling the
`work!` method. If the app is already provisioned, `work!` will be
called directly, otherwise provisioning will be requested and `work!`
will not be called until provisioning is accepted.

`work!` should return the number of seconds to wait before calling it
again.


