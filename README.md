# Instant mTLS with Identity Plus

Building an mTLS service/API gateway based on SSL client certificate authentication and role based authorization using identity plus, Openresty/Nginx and Lua.

## Requirements

- A small VPC in any cloud environment. This can be substituted with a Docker environment on a single (potentially local machine)
- A LAN defined within the VPC (or inside the Docker environemnt) that connects instances (VMs or containers) within the enviornment
- We are going to be working with 3 VMs (for testing purposes any configuration will do, 512MB of RAM, 1-2 vCPUs, 30GB disk space). Most of this capacity is needed to support the Linux envioronment on which the demo will run, so please calibrate your needs to that
- The demo is based on x86 64bit architecture, so for simplicity we recommend using that. The demo can be adapted to other architectures by modifying docker base image URLs. We recommend doing that after gaining some experience.
- Each VM will have to be connected to the LAN, and one VM (the one hosting the mTLS Gateway) should be attached a public IP as well
- If a Load Balancer (ALB, ELB, or any cloud load balancer) is configured in front of the mTLS Gateway, please make sure the balancing is at TCP layer (not HTTP). The mTLS Gateway must own the TLS offloading process. Mutual TLS connections cannot be man-in-the-middled (it is the way they are supposed to be) so if there is a proxy offloading and re-ncapsulating the communication between the client and the mTLS Gateway, the "m" part of the TLS will be lost and client certificate authentication will fail.

## Installation Steps

### 1. Sign up for an Identity Plus Indetity

Essentially issuing your first client certificate for your first end-user device. Go to https://signon.identity.plus and follow the steps. Once the certificate is installed you may have to restart your browser (sometimes an incognito window is sufficient). This happens because browsers are caching TLS sessions and do not immediately pick up the client certificate. This technique that is not standardized so your experience may vary depending on your OS and your browser. The process is successful when you are able to login into https://my.identity.plus, using the previousely installed client certifcate.

### 2. Create your first organizations

After step 1 is completed and you are able to log into your Identity Plus account, follow the link to https://platform.identity.plus. You will have no organizations at this point, so follow the clues. Chose Personal plan for development and testing purpose stuff and give your organization a name.

Please chose your organization id well. This is important because your organization will be assigned a subdomain trunk in the .mtls.app domain, like your-org-id.mtls.app, which will be unique to your organization. All of your serivces under that organization will be assigned subdomains in this subdomain trunk. The organization id can be change later, but it may imply a lot of work, because all service domains will be changed and server certificates will need to be re-issued.

### 3. Creating the 4 services

Once your organization is created we will configure four services in the Identity Plus platform, the three internal, VPC based services, and one that we will use as a mock service to serve as a 3rd Party service for testing purposes. This one will not require a deployment, but we do need it for administrative (management) purposes.

As a note from a naming perspective, like with the organization, these services can in principle be named any way, and the name can be changed later, with less work than the organization but still some administrative overhead. For ease of the process, let's use the service names specified in this documentation, simply beacuse the deployment config files are pre-configured with those names and so we eliminate some complexity during the testing. Service names need not be unique world-wide, only organization wide, because each service id will be suffixed with the .your-org.mtls.app subdomain which will give it a unique glabal uri (identitifier).

#### 4.1 Creating "Mtls Rbac Gateway" service

In the "Services" page under "Your Organization" let's click "Create Service" and give it the name "Mtls Rbac Gateway".

Once created, let's enter the service, and in the "Identity" menu, "Identity & Ownership section", let's change the domain prefix (subdomain) to "rbac". the rest of the trunk will be immutable (your-org.mtls.app).

#### 4.2 Creating "Minio Object Storage" service

Following the patter in 4.1, let's just name it "Minio Object Storage". Also let's just use a simpler domain and change the subdomain prefix to "minio".

#### 4.3 Creating "Internal Client" service

Following the patter in 4.1, let's just name it "Internal Client". Also let's just use a simpler domain and change the subdomain prefix to "int".

#### 4.4 Creating "3rd Party Client" service

Following the patter in 4.1, let's just name it "3rd Party Client". Also let's just use a simpler domain and change the subdomain prefix to "ext".

### 5. Service Discovery

Identity Plus relies on Intenet standard, DNS based service discovery, so it can be plugged in seamlessly into any internal or public internal/Internet or mixed scenario. The domain names we configured earlier are public domain names, resolvable from anywhere in the world, once configured, which is what we need to do at this step.

The demo is configured to use DNS resolution, so it is independent of the IP adderess range in your VPC, but the domain names need to be mapped to those IP addresses. Depending on the cloud you use, this step can be configured either prior, during or after the deployment of service, depending on the mode in which IP allocation works, manual, DHCP, and their specific mode of operation.

This mapping can be done in DNS section of each service, once you know the IP addresses of each service, relative to network they will be part of.

In this demo, all service have an internal IP address, with the exception of the mTLS Gateway, which also has an external IP address, as it is doing the RBAC (Role Based Access Control) both internally and externally, and will be accepting and routing traffic accordingly.

Let's configure for each service their internal addresses. For this we will create two DNS records, an empty record (for the service root) and a wildcard record for any subdomain of that service.

#### 5.1 "Mtls Rbac Gateway"

For internal resolution (discovery) let's create
- "".rbac.your-org.mtls.app ---> 10.0.0.2
- "*".rbac.your-org.mtls.app ---> 10.0.0.2

Please adapt the IP address to the actual internal IP address of the server the service runs on. As a note, once created, the empty (root) subdomain, will appear with n/a as prefix.

The role of the * is to reslve any address ending with the rbac service (mTLS Gateway is a service itself), which means that we can then internally map any services to route via the Gateway using FQDN. For example, we can use minio.rbac.your-org.mtls.app to resolve internally the MinIO service API, but not directly, rather via the mTLS Gateway. We will block the direct route (see deployment scripts) to ensure all traffic is possible only via the mTLS Gateway.

The mTLS Gateway can operate both modes, internal and/or external. From an authentication and mTLS perspective, it is compeltely netwwork agnostic, however, from a discovery perspective we do have to provide naming for external resolution also. As the Gateway's purpose is specifically to expose internal services, instead of exposing the services directly (also possible with Identity Plus but a different deployment scenario), the mTLS Gateway can map multiple endopoints to multiple (virtual) hosts, each represeing a workload, service or an API in the back-end. 

For our current installation we will create the following subdomain mappings:
- "identityplus".rbac.your-org.mtls.app ---> 123.456.789.999 (this subdomain maps to the public IP of the mTLS Gateway, and it's purpose is to expose the mTLS Gateway itself, more specifically the Identity Plus diagnostics and cache clearing mechanisms)
- "minio-admin".rbac.your-org.mtls.app ---> 123.456.789.999 (will use this to expos the MinIO admin interface which the mTLS Gateway will route - provided roles - upstream to MinIO service port 9001, where the admin console is)
- "minio-service".rbac.your-org.mtls.app ---> 123.456.789.999 (will use this to expos the MinIO API interface which the mTLS Gateway will route - provided roles - upstream to MinIO service API 9000, where the API is published)

Please replace the above - otherwise impossible - IP addressess, with the appropriate IP address, you own.

#### 5.2 "Minio Object Storage"

For internal resolution (discovery) let's create
- "".minio.your-org.mtls.app ---> 10.0.0.3
- "*".minio.your-org.mtls.app ---> 10.0.0.3

Simlarly, please adapt the IP address. This will be important as the load balancer will route traffic to the MinIO service

#### 5.3 "Internal Client"

For internal resolution (discovery) let's create
- "".int.your-org.mtls.app ---> 10.0.0.4
- "*".int.your-org.mtls.app ---> 10.0.0.4

This is less important as the purpose of this service at this point is to be only clinet, so nobody will try to resolve it.

#### 5.4 "3rd Party Client"

For internal resolution (discovery) let's create
- "".int.your-org.mtls.app ---> 192.168.0.123
- "*".int.your-org.mtls.app ---> 192.168.0.123

This will likely be on your local machine so it should have your public IP address as you reach out across the Internet, but similarly, it is less important as the purpose of this service at this point is to be only clinet, so nobody will try to resolve it.

### 6. Deployment

### 6.1 Deoploying the mTLS Gateway service

In our particular case, we will deploy the mTLS Gateway first, to trigger the above IP address allocation by the (in our case impossible to control) DHCP service. 10.0.0.1 being the network gateway (router) the first allocated IP in the virtual lan/subnet, will be 10.0.0.2. Otherwise there is no hard requirement with respect to the order of deployment.

In the repository, there is a folder called "Instant mTLS Demo", which contains several scripts. These scripts contain shell comands necessary to deploy, preconfigure, and test the entire setup. Please open the mtls-gateway.sh file, and find the section: "this will be manual from here on". There are a few steps that need to be performed manually, but the rest can be autoconfigured as an initialization script. This line is the demarcation. Please copy all the text before this like and use it as an initialization script to deploy your first VM in the VPC. Please name the VM suggestively, otherwise for requirements, follow the recommendations from the beginning of this file.

As a summary, the script will: 
    - remove password authentication from SSH (do not forget to add an SSH key to your VM launch configuration)
    - performs an OS update with latest fixes
    - it will install docker (these two steps will take some time, so even if you log into the VM, this may be ongoing in the background, so please give it a few minutes)
    - configures ufw and closes all ports except 22 and 443 (you may have to adjust network interface names, in our example public inteface is eth0 and internal interface is enp70s)

Lunch the VM and we recommend that at this point you give it some time.

### 6.2 Deoploying the MinIO Service

For the same IP address allocation reason, we will configure the MinIO service. The difference here is that all of the minio-service.sh file is initialization script (there are no manual steps). So please follow the exact steps as above, with a different name and initialization script.

As a summary, the script will:
- remove password authentication from SSH (do not forget to add an SSH key to your VM launch configuration)
- performs an OS update with latest fixes
- it will install docker (these two steps will take some time, so even if you log into the VM, this may be ongoing in the background, so please give it a few minutes)
- configures ufw and closes all ports except 22 and 443 (you may have to adjust network interface names, in our example public inteface is eth0 and internal interface is enp70s)
- configures IP tables to block all traffic that is not for the minio service, otherwise docker and UFW have conflicting rules which meeans that docker overrides UFW and exposes all ports. And while this is internal, in order to ensure mTLS rigor and prevent lateral movement, we want to allow traffic to the minIO service only via the mTLS gateway
- launches the docker version of the minIO service, available in the docker repos, using some default credentials, which have little significance since we will be using mTLS authentication for access 

### 6.3 Deploying the Internal Client service

Last one is client service machine, which is more or less similar with the previous ones, but the majority of the steps are manual there, as most of the commands are meant for testing. The pattern is the same, with the exception that there is not docker.


## 7 Post Deployment Configurations

### 7.1 Configuring the mTLS Gateway

By this time, the initialization script should have finished on the mTLS Gateway machine, so please ssh into the machine and follow the rest of the steps (the manual ones) in the mtls-gateway.sh:

- Clone the mtls git repos into the /opt directory
- Build the docker image: The docker image build is personalized, and it will connect the mTLS Gageway instance to your Identity Plus authority account. To achieve this, you need an autoprovisioning token from the Identity Plus platform dashboard and replace this "AUTOPROVISION-TOKEN-FROM-IDENTITY_PLUS" text with in when you execute the build. To get the token, please go to the "Mtls Rbac Gateway" service in https://platform.identity.plus/organization/your-org/service/your-service/agents and click "Auto Provisioning Token".
- Once the build is completed, run the image with the last command in the file.


### 7.2 Testing The Deployment

At this point your environment is up and running and given IP addresses are correctly configured, the gateway is already routing traffic both internally and from outside to your MinIO service instance, and performs authentication and role based access control based on the default routing and access control rules.

Given the mTLS service is part of the organization you created in Identity Plus Platform, and that you are administrator in the organization, you can now access the mTLS Gateway from your local machine. You can now visit https://rbac.your-org.mtls.app, to see the mTLS Gateway diagnostic page. This will tell you whether the Identity Plus integration is working properly. You can also use this page to clear the caches and force all certificates to be revalidated upon nex arrival.

### 7.2 Connecting MinIO Service to the mTLS Gateway

Identity Plus is designed around the concept of the "perimeter of one". That means the mTLS security model is fully decentralized, end to end security model. Each service, no matter how small, is capable to implement Identity Plus mTLS ID based authentication and ensure periemter grade security by itself. It does not need any other service or front-facing gateway for this feature. However, if a service cannot implenet that due to any number of reasons (for example is a legacy service or we don't have access to the service itself), the way it is with our MinIO Service deployment, we can front-end it with a Gatweay service.

However, when we frontend a service with a gateway service, the gateway service will make validation calls to Identity Plus in the name of the font-ended service. In our case, the mTLS Gateway, will make calls to Identity Plus, in the name of the MinIO Service, to authenticate clients of the MinIO service. For security, Identity Plus requires that the mTLS Gateway service, be designated the "administrator" or "manager" role by the front-ended service.

1. Please go to your "Mtls Rbac Gateway" service in Identity Plus platform, "Identity" menu and copy the domain name of the service into your clipboard
2. Then go the your "MinIO Service" service in Idnetity Plus platform, "Service" menu and make the MTLS RBAC Gateway a manger service, using the domain name from your clipboard.
3. Now the mTLS Gateway can proxy authenticated calls into the MinIO service. You can go to https://minio-admin.your-org.mtls.app from your browser, because you are an adminstrator in the MinIO Service, as you are in all your services.
4. You need to authenticated with the default credentials into the service. This happens because MinIO service is not aware of the mTLS authentication. When Identity Plus is implemented such that it is aware, authentication becomes 100% transparent

## 8 Your mTLS Sand Box

This concludes the mTLS perimeter configuration. As mentioned earlier, this type of access control and security is highly distributed, and with the deployment being very nimble, light resource with full automatic capabilities (the mTLS Gateway Docker instance will refresh its own certificate without manual intervention) this deployment can be scaled to any number of service. Alternatively, the mTLS Gateway is highly configurable. It can manage many upstream services, and perform mTLS authentication for them, even offload certificate inforamtion, user and role information to upstream services. 

That being said, let's configure automated clients for this mTLS authenticating service to see how access and automation works from the client perspective.

### 8.1 Configuring an internal client

The Identity Plus digital Identity has two major categories. People are the only stand alone category conceptually - a person can have a self containe, governed by nobody but the owner identity - however, people can be members of organizations and organizations may have services. Services, while subordinated to a human entity, can have separate Identities, and like people, can have associated devices, which can authenticate with mTLS IDs. Onse such service example is the one we defined earlier, "Internal Client".

By this time, the machine likely provisioned and the OS update has been performed. So all we need to do is to install the Identity Plus client automation, which is very similar to the automateion we did on the service, but simples. Almost everything is TLS and mTLS compatible on the Internet, so in principle all we need to to is two steps, configure the mtls ID provisioning, and configuring the client with the necessary SSL/TLS context to use the X.509 client certificate to authenticate. 

Please SSH into the "Internal Client" machine and follow the client.sh manual steps to configure the automation (all steps are configured in the shell script)
- go the the already cloned Identity Plus cli directory
- perform the build
- get the autoprovisioning token as above, with the mention that this time you need to get if from the "Internal Client" service, as this machine rerpesent that service
- get the Identity Plus trust store, you need this if you work with Identity Plus issued server certificates which are not globally trusted, such as in this demo, otherwise you don't need it.
- install certificate rotation automation
- make a curl call directly to your MinIO service - if all configured correctly access will not be granted and you will observe your curl call hanging
- make a curl call via the mTLS service. The call will get a response, but at this stage you will be denied, because client service is nobody at this stage to MinIO service

### 8.2 Configuring roles

To overcome the error from the above attempt we need to give a role in MinIO service to Internal Client service, 

1. please go to the MinIO Service, in the Identity Plus dashboard, "Access Management" menu and create a role "Customer"
2. Then go (perhaps in a new tab) to your "Internal Client" service, "Identity" menu and copy the service identification domain.
3. return to MinIO Service, the "Services" menu under "Access Management"
4. make "Internal Client" (int.your-org.mtls.app) a "Customer"
5. wait 5 minutes or go to https://identityplus.rbac.your-org.mtls.app and purge the cache
6. you can now repeat the call and the client will get the results


### 8.3 3rd Party Clients

The Identity Plus identity and access control mechanism is fully decentralized, meaning that services, such as MinIO Service or the mTLS Gateway are not responsible for identity elements. This means you can seamlessly scale access to outside entities. To test the functionality, reapeat everything from 8.2 on your machine, but using "External Client" service as the Identity anchor. You will also have to clone the Identity Plus cli (command line interface) repo, but the instructions are in the automated lines in the clients.sh script file.

Also, when making calls from your local machine, please use the external domain anchor points, as you are now making connections across the Internet. Use https://minio-service.rbac.your-org.mtls.app, to access the service across the mTLS Gateway from the Internet.

## Wrap Up

That concludes the demo, which contains all generic steps to integrate Idnetity Plus access control within your production environment, zero-trust from corporate to production - even if your corporate embraces BYOD model - and authenticate third party service across the Internet.

Feel free to reach out to us if you have any questions, or need our assistance with more custom use-cases: support@identity.plus 