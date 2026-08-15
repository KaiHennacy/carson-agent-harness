# Dedicated self-publish interface

Publishing is intentionally a separate agentic task from development and local
validation.

The publishing session must operate on a clean export of this generic repository
source. It must not copy runtime state, instance manifests, session ledgers,
event logs, A/B history, credentials, or private development evidence.

## Required publication inputs

The later publishing task must receive these values externally:

```text
CARSON_PUBLISH_REPOSITORY
CARSON_PUBLISH_BRANCH
CARSON_PUBLISH_REMOTE_URL
```

Example repository value:

```text
owner/repository
```

No repository owner or destination is hard-coded in this project.

Authentication is also external. The repository does not store a token, SSH
private key, password, or credential helper configuration.

## Required pre-push gates

Before a publishing session may push, it must:

1. run `bash ./validate.sh`;
2. confirm the source tree contains no runtime/private material;
3. confirm the Git remote exactly matches `CARSON_PUBLISH_REMOTE_URL`;
4. create a commit from generic repository source only;
5. report the commit ID and exact destination before or with the push result;
6. never alter any already-running harness instance as part of publication.

## Post-publish acceptance

A separate context-free session must later clone the published repository,
install it using environment-provided Download/A/B paths, create a new unique
instance, start it, list it, accept a correctly routed download task, and
produce an A/B next-message cycle without relying on development-instance state.
