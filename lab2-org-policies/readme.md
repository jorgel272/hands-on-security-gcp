Demo 

https://console.cloud.google.com/welcome?organizationId=792573034594&cloudshell=true

https://console.cloud.google.com/iam-admin/orgpolicies/list?project=jorgeliauwnl

1. Check existing org. polices
2. Go to project jorgeliauwnl 
3. Create Compute Engine select region 

Apply Organisation Policy for resource location

Create yaml file
nano cc-restrict-gcp-location-policy.yaml

constraint: constraints/gcp.resourceLocations
listPolicy:
  allowed_values:
    in:europe-west4-locations

gcloud beta resource-manager org-policies set-policy cc-restrict-gcp-location-policy.yaml --project  jorgeliauwnl

4. Create Compute Engine and select region