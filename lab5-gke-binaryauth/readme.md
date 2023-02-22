Overview
Google Kubernetes Engine and its underlying container model provide increased scalability and manageability for applications hosted in the Cloud. It's easier than ever to launch flexible software applications according to the runtime needs of your system.

This flexibility, however, can come with new challenges. In such environments, it can be difficult to ensure that every component is built, tested, and released according to your best practices and standards, and that only authorized software is deployed to your production environment.

Binary Authorization (BinAuthz) is a service that aims to reduce some of these concerns by adding deploy-time policy enforcement to your Kubernetes Engine cluster. Policies can be written to require one or more trusted parties (called “attestors”) to approve of an image before it can be deployed. For a multi-stage deployment pipeline where images progress from development to testing to production clusters, attestors can be used to ensure that all required processes have completed before software moves to the next stage.

The identity of attestors is established and verified using cryptographic public keys, and attestations are digitally signed using the corresponding private keys. This ensures that only trusted parties can authorize deployment of software in your environment.

At deployment time, Binary Authorization enforces the policy you defined by checking that the container image has passed all required constraints -- including that all required attestors have verified that the image is ready for deployment. If the image passes, the service allows it to be deployed. Otherwise, deployment is blocked and the image cannot be deployed until it is compliant.

Binary autorization diagram.

What you'll build
This lab describes how to secure a GKE cluster using Binary Authorization. To do this, you will create a policy that all deployments must conform to, and apply it to the cluster. As part of the policy creation, you will create an attestor that can verify container images, and use it to sign and run a custom image.

The purpose of this lab is to give a brief overview of how container signing works with Binary Authorization. With this knowledge, you should feel comfortable building a secure CI/CD pipeline, secured by trusted attestors.

What you'll learn
How to enable Binary Authorization on a GKE cluster.
How to define a Binary Authorization policy.
How to create an attestor and associate it with the policy.
How to sign an image as an attestor.
Roles
Because Binary Authorization concerns the security of your infrastructure, it will typically be interacted with by multiple people with different responsibilities.

In this lab, you will be acting as all of them. Before getting started, it's important to explain the different roles you'll be taking on.

Deployer role. Deployer

This person/process is responsible for running code on the cluster.
They aren't particularly concerned with how security guarantees are enforced, that's someone else's job.
May be a Software Engineer or an automated pipeline.
Policy creator role. Policy Creator

This person is responsible for the big picture security policies of the organization.
Their job is to make a checklist of rules that must be passed before a container can run.
They're in charge of the chain of trust, including who needs to sign off an image before it can be considered safe.
They're not necessarily concerned with the technical details of how to conform to the rules.
They might not even know what the software in a container does.
They just know about what needs to be done before trust can be established.
Attestor role. Attestor

This person/process is responsible for one link in the chain of trust of the system.
They hold a cryptographic key, and sign an image if it passes their approval process.
While the Policy Creator determines policy in a high-level, abstract way, the Attestor is responsible for concretely enforcing some aspect of the policy.
May be a real person, like a QA tester or a manager, or may be a bot in a CI system.
The security of the system depends on their trustworthiness, so it's important that their private keys are kept secure.
Each of these roles can represent an individual person, or a team of people, in your organization. In a production environment, these roles would likely be managed by separate Google Cloud projects, and access to resources would be shared between them in a limited fashion using Cloud IAM.

Organogram of binary authorization GKE deployment roles.

Note: Because you will be playing all these roles over the course of this lab, you will see annotations indicating which role is responsible for each step.
Setup and requirements
Before you click the Start Lab button
Read these instructions. Labs are timed and you cannot pause them. The timer, which starts when you click Start Lab, shows how long Google Cloud resources will be made available to you.

This hands-on lab lets you do the lab activities yourself in a real cloud environment, not in a simulation or demo environment. It does so by giving you new, temporary credentials that you use to sign in and access Google Cloud for the duration of the lab.

To complete this lab, you need:

Access to a standard internet browser (Chrome browser recommended).
Note: Use an Incognito or private browser window to run this lab. This prevents any conflicts between your personal account and the Student account, which may cause extra charges incurred to your personal account.
Time to complete the lab---remember, once you start, you cannot pause a lab.
Note: If you already have your own personal Google Cloud account or project, do not use it for this lab to avoid extra charges to your account.
How to start your lab and sign in to the Google Cloud Console
Click the Start Lab button. If you need to pay for the lab, a pop-up opens for you to select your payment method. On the left is the Lab Details panel with the following:

The Open Google Console button
Time remaining
The temporary credentials that you must use for this lab
Other information, if needed, to step through this lab
Click Open Google Console. The lab spins up resources, and then opens another tab that shows the Sign in page.

Tip: Arrange the tabs in separate windows, side-by-side.

Note: If you see the Choose an account dialog, click Use Another Account.
If necessary, copy the Username from the Lab Details panel and paste it into the Sign in dialog. Click Next.

Copy the Password from the Lab Details panel and paste it into the Welcome dialog. Click Next.

Important: You must use the credentials from the left panel. Do not use your Google Cloud Skills Boost credentials.
Note: Using your own Google Cloud account for this lab may incur extra charges.
Click through the subsequent pages:

Accept the terms and conditions.
Do not add recovery options or two-factor authentication (because this is a temporary account).
Do not sign up for free trials.
After a few moments, the Cloud Console opens in this tab.

Note: You can view the menu with a list of Google Cloud Products and Services by clicking the Navigation menu at the top-left. Navigation menu icon
Activate Cloud Shell
Cloud Shell is a virtual machine that is loaded with development tools. It offers a persistent 5GB home directory and runs on the Google Cloud. Cloud Shell provides command-line access to your Google Cloud resources.

Click Activate Cloud Shell Activate Cloud Shell icon at the top of the Google Cloud console.
When you are connected, you are already authenticated, and the project is set to your PROJECT_ID. The output contains a line that declares the PROJECT_ID for this session:

Your Cloud Platform project in this session is set to YOUR_PROJECT_ID
gcloud is the command-line tool for Google Cloud. It comes pre-installed on Cloud Shell and supports tab-completion.

(Optional) You can list the active account name with this command:

gcloud auth list
Copied!
Click Authorize.

Your output should now look like this:

Output:

ACTIVE: *
ACCOUNT: student-01-xxxxxxxxxxxx@qwiklabs.net
To set the active account, run:
    $ gcloud config set account `ACCOUNT`
(Optional) You can list the project ID with this command:

gcloud config list project
Copied!
Output:

[core]
project = <project_ID>
Example output:

[core]
project = qwiklabs-gcp-44776a13dea667a6
Note: For full documentation of gcloud, in Google Cloud, refer to the gcloud CLI overview guide.
Setting the project
Deployer role. You're the Deployer.

Run the following command in Cloud Shell to set the PROJECT_ID variable:

export PROJECT_ID=$(gcloud config get-value project)
Copied!
Enabling the APIs
Before using Binary Authorization, allow Kubernetes Engine to manage your cluster and BinAuthz to manage the policy on the cluster.

Run the following to enable the relevant APIs in your Google Cloud project:

gcloud services enable \
    container.googleapis.com \
    containeranalysis.googleapis.com
Copied!
Alternatively, enable the Binary Authorization through the Google Cloud API Library.

Search for "binary authorization" in the search field, then click on the Binary Authorization API tile.
Click the Enable button.
Click Check my progress to verify the objective.
Enabling the APIs

Setting up a cluster
Next, set up a Kubernetes cluster for your project through Kubernetes Engine.

The following command will create a new cluster named binauthz-lab in the zone us-central1-a with binary authorization enabled:

gcloud beta container clusters create \
    --enable-binauthz \
    --zone us-central1-a \
    binauthz-lab
Copied!
Creating a cluster can take a few minutes to complete.

Once your cluster has been created, add it to your local environment so you can interact with it locally using kubectl:

gcloud container clusters get-credentials \
    --zone us-central1-a \
    binauthz-lab
Copied!
Running a pod
Add a container to your new cluster.

The following command will create a simple Dockerfile you can use:

cat << EOF > Dockerfile
   FROM alpine
   CMD tail -f /dev/null
EOF
Copied!
This container will do nothing but run the tail -f /dev/null command, which will cause it to wait forever. It's not a particularly useful container, but it will allow you to test the security of your cluster.

Build the container and push it to Google Container Registry (GCR):

export CONTAINER_PATH=us.gcr.io/$PROJECT_ID/hello-world
docker build -t $CONTAINER_PATH ./
gcloud auth configure-docker --quiet
docker push $CONTAINER_PATH
Copied!
You should now be able to see the newly created container in the Container Registry in the Console (Navigation menu > Container Registry).

The Container Registry navigation menu.

Now, run the container on your cluster:

kubectl create deployment hello-world --image=$CONTAINER_PATH
Copied!
If everything worked well, your simple container should be silently running.

You can verify this by listing the running pods:

kubectl get pods
Copied!
Output:

NAME                           READY     STATUS    RESTARTS   AGE
hello-world-75c78845f6-t67l8   1/1       Running   0          8s
Click Check my progress to verify the objective.
Setting up a Cluster

Task 1. Securing the cluster with a policy
Policy creator role. You're the Policy Creator.

Adding a policy
Once you have a cluster set up and running your code, you can secure the cluster with a policy.

To start, you create a policy file:

cat > ./policy.yaml << EOM
    globalPolicyEvaluationMode: ENABLE
    defaultAdmissionRule:
      evaluationMode: ALWAYS_DENY
      enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
EOM
Copied!
This policy is relatively simple. The globalPolicyEvaluationMode line declares that this policy extends the global policy defined by Google. This allows all official GKE containers to run by default. Additionally, the policy declares a defaultAdmissionRule that states that all other pods will be rejected. The admission rule includes an enforcementMode line, which states that all pods that are not conformant to this rule should be blocked from running on the cluster.

For instructions on how to build more complex policies, look through the Binary Authorization documentation.

Note: While developing a policy, you may want to make use of dryrun mode. This mode will allow all pods to run, but will log any policy violation events to the audit log.
Binary authorization policy diagram.

Now you can apply the policy to your project by running the following command:

gcloud container binauthz policy import policy.yaml
Copied!
Deployer role. You're the Deployer.

Testing the policy
Your new policy should prevent any custom container images from being deployed on the cluster.

You can verify this by deleting your pod and attempting to run it again:

kubectl delete deployment --all
kubectl delete event --all
kubectl create deployment hello-world --image=$CONTAINER_PATH
Copied!
If you check the cluster for pods, you should notice that no pods are running this time:

kubectl get pods
Copied!
You may need to run the command a second time to see the pods disappear – kubectl checked the pod against the policy, found that it didn't conform to the rules, and rejected it.

You can see the rejection listed as a kubectl event:

kubectl get event --template \
    '{{range.items}}{{"\033[0;36m"}}{{.reason}}:{{"\033[0m"}}{{.message}}{{"\n"}}{{end}}'
Copied!
Output:

Output of kubectl event.

Note: The above command can be run without the template string. The template was added to improve readability of the output.
Click Check my progress to verify the objective.
Securing the Cluster with a Policy

Task 2. Understanding container analysis
Attestors in Binary Authorization are implemented on top of the Cloud Container Analysis API, so it is important to describe how that works before going forward.

The Container Analysis API was designed to allow you to associate metadata with specific container images.

Container analysis concepts
Note: This represents a piece of metadata in a generalized way. It's associated with the Google Cloud project of whoever created it, not with any particular container image.
Occurrence: This represents a single instance of a Note associated with a specific container.
While a Note can describe a vulnerability in an abstract way, an Occurrence describes how that Note manifests itself in a specific container image.
As an example, a Note might be created to track the Heartbleed vulnerability. Security vendors would then create scanners to test container images for the vulnerability, and create an Occurrence associated with each compromised container.

Container analysis API tracking the Heartbleed vulnerability diagram.

Along with tracking vulnerabilities, Container Analysis was designed to be a generic metadata API.

Binary Authorization utilizes Container Analysis to associate signatures with the container images they are verifying. A Container Analysis Note is used to represent a single attestor, and Occurrences are created and associated with each container that attestor has approved.

The Binary Authorization API uses the concepts of "attestors" and "attestations", but these are implemented using corresponding Notes and Occurrences in the Container Analysis API.

Binary authorization API diagram.

Task 3. Setting up an attestor
Currently, the cluster will perform a catch-all rejection on all images that don't reside on an official repository.

Your next step is to create an attestor, so you can selectively allow trusted containers.

Attestor role. You're the Attestor.

Creating a container analysis note
Container analysis API diagram with Note.

Start by creating a JSON file containing the necessary data for your Note.

This command will create a JSON file containing your Note locally:

cat > ./create_note_request.json << EOM
{
  "attestation": {
    "hint": {
      "human_readable_name": "This note represents an attestation authority"
    }
  }
}
EOM
Copied!
Now, submit the Note to your project using the Container Analysis API:

export NOTE_ID=my-attestor-note
curl -vvv -X POST \
    -H "Content-Type: application/json"  \
    -H "Authorization: Bearer $(gcloud auth print-access-token)"  \
    --data-binary @./create_note_request.json  \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}"
Copied!
You can verify the Note was saved by fetching it back:

curl -vvv  \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/${NOTE_ID}"
Copied!
Creating an attestor in binary authorization
Binary authorization diagram with Attestor.

Your Note is now saved within the Container Analysis API.

To make use of your attestor, you must also register the note with Binary Authorization:

export ATTESTOR_ID=my-binauthz-attestor
gcloud container binauthz attestors create $ATTESTOR_ID \
    --attestation-authority-note=$NOTE_ID \
    --attestation-authority-note-project=${PROJECT_ID}
Copied!
To verify everything works as expected, print out the list of registered authorities:

gcloud container binauthz attestors list
Copied!
Binauthz attestors list output.

Adding a KMS key
Binary authorization KMS key diagram.

Before you can use this attestor, your authority needs to create a cryptographic key pair that can be used to sign container images. This can be done through Google Cloud Key Management Service (KMS).

To start, you add some environment variables to describe the new key:

export KEY_LOCATION=global
export KEYRING=binauthz-keys
export KEY_NAME=lab-key
export KEY_VERSION=1
Copied!
Create a keyring to hold a set of keys:

gcloud kms keyrings create "${KEYRING}" --location="${KEY_LOCATION}"
Copied!
Create a new asymmetric signing key pair for the attestor:

gcloud kms keys create "${KEY_NAME}" \
    --keyring="${KEYRING}" --location="${KEY_LOCATION}" \
    --purpose asymmetric-signing  --default-algorithm="ec-sign-p256-sha256"
Copied!
You should see your key in the Cloud Console by going to Navigation menu > Security > Cryptographic Keys.

Now, associate the key with your authority through the gcloud binauthz command:

gcloud beta container binauthz attestors public-keys add  \
    --attestor="${ATTESTOR_ID}"  \
    --keyversion-project="${PROJECT_ID}"  \
    --keyversion-location="${KEY_LOCATION}" \
    --keyversion-keyring="${KEYRING}" \
    --keyversion-key="${KEY_NAME}" \
    --keyversion="${KEY_VERSION}"
Copied!
You can print the list of authorities again:

gcloud beta container binauthz attestors list
Copied!
You should now see a key registered:
Binauthz attestors list output.

Note: Multiple keys can be registered for each authority. This can be useful if the authority represents a team of people. For example, anyone in the QA team could act as the QA Attestor, and sign with their own individual private key.
Click Check my progress to verify the objective.
Setting Up an Attestor

Task 4. Signing a container image
Attestor role. You're the Attestor.

Now that you have your authority set up and ready to go, you can use it to sign the container image you built previously.

Creating a signed attestation
An attestation must include a cryptographic signature to state that a particular container image has been verified by the attestor and is safe to run on your cluster.

To specify which container image to attest, you need to determine its digest.

You can find the digest for a particular container tag hosted in the Container Registry by running:

export DIGEST=$(gcloud container images describe ${CONTAINER_PATH}:latest \
    --format='get(image_summary.digest)')
Copied!
Now you can use gcloud to create your attestation. The command simply takes in the details of the key you want to use for signing, and the specific container image you want to approve.

gcloud beta container binauthz attestations sign-and-create  \
    --artifact-url="${CONTAINER_PATH}@${DIGEST}" \
    --attestor="${ATTESTOR_ID}" \
    --attestor-project="${PROJECT_ID}" \
    --keyversion-project="${PROJECT_ID}" \
    --keyversion-location="${KEY_LOCATION}" \
    --keyversion-keyring="${KEYRING}" \
    --keyversion-key="${KEY_NAME}" \
    --keyversion="${KEY_VERSION}"
Copied!
In Container Analysis terms, this will create a new occurrence, and attach it to your attestor’s note.

To ensure everything worked as expected, you can list your attestations:

gcloud container binauthz attestations list \
   --attestor=$ATTESTOR_ID --attestor-project=${PROJECT_ID}
Copied!
Now, when you attempt to run that container image, Binary Authorization will be able to determine that it was signed and verified by the attestor and it is safe to run.

Task 5. Running a signed image
Now that you have your image securely verified by an attestor, let's get it running on the cluster.

Policy creator role. You're the Policy Creator.

Updating the policy
Currently, your cluster is running a policy with one rule: allow containers from official repositories, and reject all others.

Change the policy to allow any images verified by the attestor:

cat << EOF > updated_policy.yaml
    globalPolicyEvaluationMode: ENABLE
    defaultAdmissionRule:
      evaluationMode: REQUIRE_ATTESTATION
      enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
      requireAttestationsBy:
      - projects/${PROJECT_ID}/attestors/${ATTESTOR_ID}
EOF
Copied!
You should now have a new file on disk, called updated_policy.yaml. Now, instead of the default rule rejecting all images, it first checks your attestor for verifications.

Binary authorization policy update diagram.

Upload the new policy to Binary Authorization:

gcloud container binauthz policy import updated_policy.yaml
Copied!
Deployer role. You're the Deployer.

Running the verified image
Next you'll run the signed image and verify that the pod is running with the following command:

kubectl create deployment hello-world-signed --image="${CONTAINER_PATH}@${DIGEST}"
Copied!
Check to see if you can access the pod:

kubectl get pods
Copied!
You should see your pod has passed the policy and is running on the cluster.

You may have to run the command a second time to see the pod:

hello-world-signed-5777dc55f8-qjj9v   1/1       Running   0          7s
Copied!
If you open the Navigation menu and select Kubernetes Engine > Workloads you will see that your pod is available:
Kubernetes Engine workloads navigation menu.

Note: When running the container image, you must now specify the specific digest you want to deploy. Tags like "latest" will not be allowed to run on the cluster. This is because image under a tag may change, so tags can't be secured with a signature like a digest can.
Click Check my progress to verify the objective.
Running Signed Image

Congratulations!
You can now make specific security guarantees for your cluster by adding more complex rules to the policy.