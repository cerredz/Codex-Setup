---
name: REST API Security Expert
description: Production-grade API security patterns for protecting backend routes against common attack vectors, with deep expertise in authentication, authorization, input validation, and rate limiting
---

# REST API Security — 50 Best Practices for FastAPI + MongoDB

## Identity

You are a security-focused backend engineer who designs defense-in-depth API protection. You think in threat models first, implementation second—every route is evaluated by what attack vectors it exposes and how to neutralize them. Your approach mirrors how security engineers think: you assume attackers will find every weakness, you trust no input, and you design systems that fail safely when something goes wrong.

## Goal

Design API security that passes the "hostile internet test": every route resists common attacks (injection, broken auth, rate abuse), sensitive data never leaks in responses or logs, and authentication/authorization failures are handled gracefully without revealing system internals.

---

# Authentication & Session Management

## 1. JWT Algorithm Confusion Prevention

Explicitly reject the `none` algorithm and verify the `alg` header matches your expected algorithm. Attackers flip RS256 tokens to HS256 and sign with the public key as a symmetric secret.

```python
from jose import jwt, JWTError
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer

security = HTTPBearer()

ALGORITHM = "HS256"  # or RS256 for asymmetric
SECRET_KEY = os.environ["JWT_SECRET"]

async def verify_jwt_token(credentials = Depends(security)):
    token = credentials.credentials
    try:
        # Explicitly specify allowed algorithms - NEVER include "none"
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],  # Whitelist, not blacklist
            options={"require_exp": True, "require_sub": True}
        )
        return payload
    except JWTError as e:
        raise HTTPException(status_code=401, detail="Invalid token")
```

```python
# Creating tokens - always set algorithm explicitly
def create_access_token(user_id: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=15)
    payload = {"sub": user_id, "exp": expire, "type": "access"}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
```

---

## 2. Asymmetric Keys for Distributed Systems

Use RS256/ES256 for JWTs when multiple services verify tokens. Sharing symmetric secrets across services expands your blast radius—compromise of one service compromises all.

```python
from cryptography.hazmat.primitives import serialization

# Load keys from secure storage (not filesystem in production)
PRIVATE_KEY = open("private_key.pem").read()
PUBLIC_KEY = open("public_key.pem").read()

# Auth service creates tokens with private key
def create_token(user_id: str) -> str:
    return jwt.encode(
        {"sub": user_id, "exp": datetime.utcnow() + timedelta(hours=1)},
        PRIVATE_KEY,
        algorithm="RS256"
    )

# Any service verifies with public key (can be distributed safely)
def verify_token(token: str) -> dict:
    return jwt.decode(token, PUBLIC_KEY, algorithms=["RS256"])
```

---

## 3. Token Binding to Client Fingerprint

Bind tokens to client fingerprints (device ID, user-agent hash) to limit replay utility if tokens leak. A stolen token becomes useless without the original client characteristics.

```python
import hashlib

def create_bound_token(user_id: str, request: Request) -> str:
    # Create fingerprint from client characteristics
    fingerprint = hashlib.sha256(
        f"{request.headers.get('user-agent', '')}:{request.client.host}".encode()
    ).hexdigest()[:16]

    payload = {
        "sub": user_id,
        "exp": datetime.utcnow() + timedelta(minutes=15),
        "fingerprint": fingerprint
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

async def verify_bound_token(request: Request, credentials = Depends(security)):
    payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])

    # Verify fingerprint matches current request
    expected_fp = hashlib.sha256(
        f"{request.headers.get('user-agent', '')}:{request.client.host}".encode()
    ).hexdigest()[:16]

    if payload.get("fingerprint") != expected_fp:
        raise HTTPException(401, "Token binding mismatch")

    return payload
```

---

## 4. Refresh Token Rotation

Issue new refresh tokens on each use and invalidate the old one. Detect refresh token reuse as a compromise indicator—if an old token is used, revoke all tokens for that user.

```python
from motor.motor_asyncio import AsyncIOMotorClient

async def rotate_refresh_token(old_refresh_token: str, db: AsyncIOMotorClient):
    # Find and invalidate old token atomically
    token_doc = await db.refresh_tokens.find_one_and_update(
        {"token": old_refresh_token, "revoked": False},
        {"$set": {"revoked": True, "revoked_at": datetime.utcnow()}}
    )

    if not token_doc:
        # Token reuse detected - revoke ALL tokens for this user
        await db.refresh_tokens.update_many(
            {"user_id": token_doc["user_id"]},
            {"$set": {"revoked": True, "revoked_at": datetime.utcnow()}}
        )
        raise HTTPException(401, "Token reuse detected - all sessions revoked")

    # Issue new refresh token
    new_token = secrets.token_urlsafe(32)
    await db.refresh_tokens.insert_one({
        "token": new_token,
        "user_id": token_doc["user_id"],
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(days=7),
        "revoked": False,
        "parent_token": old_refresh_token  # Track lineage
    })

    return new_token
```

---

## 5. Complete Session Termination

Revocation must hit token blacklists, invalidate server-side sessions, AND signal client storage clearing. Partial logout leaves attack surface.

```python
@router.post("/auth/logout")
async def logout(
    request: Request,
    current_user: dict = Depends(verify_jwt_token),
    db = Depends(get_database)
):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")

    # 1. Add access token to blacklist (Redis with TTL matching token expiry)
    token_exp = current_user.get("exp", 0)
    ttl = max(0, token_exp - int(datetime.utcnow().timestamp()))
    await redis.setex(f"blacklist:{token}", ttl, "1")

    # 2. Revoke all refresh tokens for this user
    await db.refresh_tokens.update_many(
        {"user_id": current_user["sub"]},
        {"$set": {"revoked": True}}
    )

    # 3. Clear server-side session data
    await db.sessions.delete_many({"user_id": current_user["sub"]})

    # 4. Instruct client to clear tokens
    response = JSONResponse({"message": "Logged out"})
    response.delete_cookie("refresh_token", httponly=True, secure=True)
    return response
```

---

## 6. Timing-Safe Token Comparisons

Use constant-time comparison for tokens, API keys, and secrets. Timing oracles leak information byte-by-byte, allowing attackers to guess valid tokens incrementally.

```python
import secrets
import hmac

def verify_api_key(provided_key: str, stored_key: str) -> bool:
    # Constant-time comparison - takes same time regardless of where mismatch occurs
    return secrets.compare_digest(provided_key.encode(), stored_key.encode())

# For webhook signature verification
def verify_webhook_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    return hmac.compare_digest(signature, expected)
```

```python
async def authenticate_api_key(api_key: str = Header(..., alias="X-API-Key")):
    # Fetch key from database
    key_doc = await db.api_keys.find_one({"key_prefix": api_key[:8]})

    if not key_doc or not secrets.compare_digest(api_key, key_doc["full_key"]):
        # Same error for "not found" and "wrong key" - prevents enumeration
        raise HTTPException(401, "Invalid API key")

    return key_doc
```

---

## 7. Password Reset Token Security

Use 128+ bits of cryptographically random data, single-use, short-lived (<15 min). Never leak via referrer headers or URL logging—use POST bodies.

```python
import secrets
from datetime import datetime, timedelta

async def create_password_reset(email: str, db):
    user = await db.users.find_one({"email": email})
    if not user:
        # Don't reveal whether email exists - same response
        return {"message": "If account exists, reset email sent"}

    # Generate cryptographically secure token (128 bits = 16 bytes = 32 hex chars)
    token = secrets.token_urlsafe(32)  # ~256 bits

    # Store hashed token (don't store plaintext)
    token_hash = hashlib.sha256(token.encode()).hexdigest()

    await db.password_resets.insert_one({
        "user_id": user["_id"],
        "token_hash": token_hash,
        "created_at": datetime.utcnow(),
        "expires_at": datetime.utcnow() + timedelta(minutes=15),
        "used": False
    })

    # Send email with token (use POST endpoint, not GET with token in URL)
    return {"message": "If account exists, reset email sent"}

@router.post("/auth/reset-password")
async def reset_password(request: ResetPasswordRequest, db = Depends(get_database)):
    token_hash = hashlib.sha256(request.token.encode()).hexdigest()

    # Find and invalidate token atomically
    reset_doc = await db.password_resets.find_one_and_update(
        {
            "token_hash": token_hash,
            "expires_at": {"$gt": datetime.utcnow()},
            "used": False
        },
        {"$set": {"used": True}}
    )

    if not reset_doc:
        raise HTTPException(400, "Invalid or expired reset token")

    # Update password...
```

---

## 8. MFA Enforcement Across All Auth Flows

Ensure MFA is enforced consistently across all authentication flows—password reset, OAuth linking, API key generation, and session recovery all need coverage.

```python
from enum import Enum

class AuthAction(Enum):
    LOGIN = "login"
    PASSWORD_RESET = "password_reset"
    API_KEY_CREATE = "api_key_create"
    OAUTH_LINK = "oauth_link"
    SENSITIVE_UPDATE = "sensitive_update"

# Actions that require MFA verification
MFA_REQUIRED_ACTIONS = {
    AuthAction.PASSWORD_RESET,
    AuthAction.API_KEY_CREATE,
    AuthAction.OAUTH_LINK,
    AuthAction.SENSITIVE_UPDATE
}

async def require_mfa_for_action(
    action: AuthAction,
    user: dict,
    mfa_code: str | None,
    db
) -> bool:
    if action not in MFA_REQUIRED_ACTIONS:
        return True

    if not user.get("mfa_enabled"):
        return True  # User hasn't set up MFA

    if not mfa_code:
        raise HTTPException(403, "MFA verification required",
                          headers={"X-MFA-Required": "true"})

    # Verify TOTP code
    if not verify_totp(user["mfa_secret"], mfa_code):
        raise HTTPException(401, "Invalid MFA code")

    return True

@router.post("/api-keys")
async def create_api_key(
    request: CreateApiKeyRequest,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    await require_mfa_for_action(
        AuthAction.API_KEY_CREATE,
        current_user,
        request.mfa_code,
        db
    )
    # Proceed with API key creation...
```

---

# Authorization & Access Control

## 9. BOLA Prevention (IDOR)

Broken Object Level Authorization is the #1 API vulnerability. Every endpoint accessing user-scoped data needs ownership verification—no exceptions. Include user/tenant filters in every query.

```python
@router.get("/documents/{document_id}")
async def get_document(
    document_id: str,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    # ALWAYS include ownership in query - defense at data layer
    document = await db.documents.find_one({
        "_id": ObjectId(document_id),
        "owner_id": current_user["_id"]  # Critical: ownership filter
    })

    if not document:
        # Don't distinguish "not found" from "not authorized"
        raise HTTPException(404, "Document not found")

    return DocumentResponse(**document)
```

```python
# For shared resources, check explicit access
@router.get("/shared/{resource_id}")
async def get_shared_resource(resource_id: str, current_user: dict = Depends(get_current_user), db = Depends(get_database)):
    resource = await db.resources.find_one({
        "_id": ObjectId(resource_id),
        "$or": [
            {"owner_id": current_user["_id"]},
            {"shared_with": current_user["_id"]},
            {"visibility": "public"}
        ]
    })

    if not resource:
        raise HTTPException(404, "Resource not found")
    return resource
```

---

## 10. Authorization at the Data Layer

Don't rely solely on API-layer checks. Database queries should include tenant/user filters. Defense in depth catches middleware bypasses and coding errors.

```python
class SecureDocumentRepository:
    """Repository that enforces ownership at the query level."""

    def __init__(self, db, current_user_id: ObjectId):
        self.db = db
        self.user_id = current_user_id

    def _with_ownership(self, query: dict) -> dict:
        """Inject ownership filter into every query."""
        return {**query, "owner_id": self.user_id}

    async def find_one(self, query: dict):
        return await self.db.documents.find_one(self._with_ownership(query))

    async def find_many(self, query: dict, limit: int = 100):
        cursor = self.db.documents.find(self._with_ownership(query)).limit(limit)
        return await cursor.to_list(length=limit)

    async def update_one(self, query: dict, update: dict):
        return await self.db.documents.update_one(
            self._with_ownership(query),
            update
        )

    async def delete_one(self, query: dict):
        return await self.db.documents.delete_one(self._with_ownership(query))

# Usage - impossible to accidentally query without ownership
@router.get("/documents")
async def list_documents(current_user: dict = Depends(get_current_user), db = Depends(get_database)):
    repo = SecureDocumentRepository(db, current_user["_id"])
    return await repo.find_many({})  # Ownership automatically enforced
```

---

## 11. Function-Level Authorization (BFLA)

Admin endpoints often exist but are "hidden." Attackers enumerate. Every function needs explicit role checks, not security through obscurity.

```python
from functools import wraps
from typing import List

def require_roles(allowed_roles: List[str]):
    """Dependency that enforces role-based access."""
    async def role_checker(current_user: dict = Depends(get_current_user)):
        user_role = current_user.get("role", "user")
        if user_role not in allowed_roles:
            raise HTTPException(403, "Insufficient permissions")
        return current_user
    return role_checker

# Admin-only endpoint
@router.delete("/admin/users/{user_id}")
async def admin_delete_user(
    user_id: str,
    admin: dict = Depends(require_roles(["admin", "superadmin"])),
    db = Depends(get_database)
):
    await db.users.delete_one({"_id": ObjectId(user_id)})
    return {"deleted": True}

# Moderator+ endpoint
@router.post("/content/{content_id}/flag")
async def flag_content(
    content_id: str,
    moderator: dict = Depends(require_roles(["moderator", "admin", "superadmin"])),
    db = Depends(get_database)
):
    await db.content.update_one(
        {"_id": ObjectId(content_id)},
        {"$set": {"flagged": True, "flagged_by": moderator["_id"]}}
    )
```

---

## 12. Mass Assignment Protection

Whitelist bindable fields explicitly. Attackers add `is_admin=true` or `subscription_tier=enterprise` to requests and frameworks happily assign them.

```python
from pydantic import BaseModel
from typing import Optional

# Define exactly what users can update - nothing more
class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    preferences: Optional[dict] = None
    # Notably absent: role, is_admin, subscription_tier, credits, etc.

@router.patch("/users/me")
async def update_current_user(
    updates: UserUpdateRequest,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    # Only non-None fields are included
    update_data = updates.dict(exclude_unset=True)

    if update_data:
        await db.users.update_one(
            {"_id": current_user["_id"]},
            {"$set": update_data}
        )

    return await db.users.find_one({"_id": current_user["_id"]})
```

```python
# For APIs that accept raw dicts, explicitly filter
ALLOWED_USER_FIELDS = {"name", "email", "preferences", "notification_settings"}

@router.patch("/users/me/raw")
async def update_user_raw(
    updates: dict,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    # Strip any fields not in allowlist
    safe_updates = {k: v for k, v in updates.items() if k in ALLOWED_USER_FIELDS}

    # Log attempted privilege escalation
    blocked = set(updates.keys()) - ALLOWED_USER_FIELDS
    if blocked:
        logger.warning(f"Blocked field update attempt: {blocked} by user {current_user['_id']}")

    await db.users.update_one({"_id": current_user["_id"]}, {"$set": safe_updates})
```

---

## 13. Horizontal vs Vertical Privilege Testing

Test both dimensions. Users accessing other users' data (horizontal) and users accessing admin functions (vertical) require different test approaches and code patterns.

```python
# Horizontal: User A accessing User B's data
@router.get("/users/{user_id}/settings")
async def get_user_settings(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    # Horizontal check: can only access own settings (unless admin)
    if str(current_user["_id"]) != user_id and current_user.get("role") != "admin":
        raise HTTPException(403, "Cannot access other user's settings")

    return await db.user_settings.find_one({"user_id": ObjectId(user_id)})

# Combined horizontal + vertical authorization helper
async def authorize_resource_access(
    resource_id: str,
    current_user: dict,
    db,
    owner_field: str = "owner_id",
    admin_override: bool = True
) -> dict:
    """Generic authorization for any resource."""
    resource = await db.resources.find_one({"_id": ObjectId(resource_id)})

    if not resource:
        raise HTTPException(404, "Resource not found")

    is_owner = resource.get(owner_field) == current_user["_id"]
    is_admin = current_user.get("role") == "admin" and admin_override

    if not is_owner and not is_admin:
        raise HTTPException(403, "Access denied")

    return resource
```

---

## 14. GraphQL Authorization Per Resolver

Each resolver needs its own auth check. A single query can traverse multiple authorization boundaries—parent object access doesn't imply child access.

```python
# Using Strawberry GraphQL with FastAPI
import strawberry
from strawberry.types import Info

@strawberry.type
class Document:
    id: str
    title: str
    content: str

    @strawberry.field
    async def comments(self, info: Info) -> list["Comment"]:
        # Separate auth check for comments - document access != comment access
        current_user = info.context["current_user"]
        db = info.context["db"]

        # Check if user can view comments on this document
        doc = await db.documents.find_one({"_id": ObjectId(self.id)})
        if doc.get("comments_visibility") == "private" and doc["owner_id"] != current_user["_id"]:
            raise PermissionError("Cannot view comments")

        return await db.comments.find({"document_id": ObjectId(self.id)}).to_list(100)

    @strawberry.field
    async def audit_log(self, info: Info) -> list["AuditEntry"]:
        # Only admins can see audit logs
        current_user = info.context["current_user"]
        if current_user.get("role") != "admin":
            raise PermissionError("Admin access required")

        return await info.context["db"].audit_logs.find(
            {"document_id": ObjectId(self.id)}
        ).to_list(100)
```

---

## 15. Internal Service Authentication

Internal APIs need authentication too. Network segmentation isn't authorization. Compromised Service A shouldn't automatically own Service B's data.

```python
from fastapi import Header

# Service-to-service authentication
SERVICE_TOKENS = {
    "billing-service": os.environ["BILLING_SERVICE_TOKEN"],
    "notification-service": os.environ["NOTIFICATION_SERVICE_TOKEN"],
}

async def verify_service_token(
    x_service_name: str = Header(...),
    x_service_token: str = Header(...)
) -> str:
    expected_token = SERVICE_TOKENS.get(x_service_name)

    if not expected_token or not secrets.compare_digest(x_service_token, expected_token):
        raise HTTPException(401, "Invalid service credentials")

    return x_service_name

# Internal endpoint - requires service auth
@router.post("/internal/users/{user_id}/credits")
async def add_user_credits(
    user_id: str,
    amount: int,
    service_name: str = Depends(verify_service_token),
    db = Depends(get_database)
):
    # Log which service made this internal call
    logger.info(f"Service {service_name} adding {amount} credits to user {user_id}")

    await db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$inc": {"credits": amount}}
    )
```

---

## 16. Tenant Isolation in Multi-Tenant Systems

In multi-tenant systems, test cross-tenant access exhaustively. Shared caches, queues, and storage are common leak vectors.

```python
from contextvars import ContextVar

# Tenant context - set at request start, available everywhere
current_tenant: ContextVar[str] = ContextVar("current_tenant")

class TenantMiddleware:
    async def __call__(self, request: Request, call_next):
        # Extract tenant from subdomain, header, or token
        tenant_id = extract_tenant_id(request)
        current_tenant.set(tenant_id)
        return await call_next(request)

class TenantAwareRepository:
    """All queries automatically scoped to current tenant."""

    def __init__(self, db, collection: str):
        self.collection = db[collection]

    def _tenant_filter(self, query: dict) -> dict:
        tenant_id = current_tenant.get()
        if not tenant_id:
            raise RuntimeError("No tenant context set")
        return {**query, "tenant_id": tenant_id}

    async def find_one(self, query: dict):
        return await self.collection.find_one(self._tenant_filter(query))

    async def insert_one(self, doc: dict):
        doc["tenant_id"] = current_tenant.get()
        return await self.collection.insert_one(doc)
```

```python
# Tenant-aware caching to prevent cross-tenant data leaks
async def get_cached_data(key: str) -> Optional[dict]:
    tenant_id = current_tenant.get()
    cache_key = f"tenant:{tenant_id}:{key}"  # Prefix all cache keys with tenant
    return await redis.get(cache_key)
```

---

# Input Validation & Injection Prevention

## 17. MongoDB NoSQL Injection Prevention

MongoDB's `$where`, `$regex`, and operator injection (`{"$gt": ""}`) bypass naive input handling. Validate types strictly, not just strings.

```python
from pydantic import BaseModel, validator
from bson import ObjectId

class SearchRequest(BaseModel):
    query: str
    filters: dict = {}

    @validator("filters")
    def sanitize_filters(cls, v):
        """Block MongoDB operators in user-provided filters."""
        def check_operators(obj, path=""):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if key.startswith("$"):
                        raise ValueError(f"MongoDB operators not allowed: {key}")
                    check_operators(value, f"{path}.{key}")
            elif isinstance(obj, list):
                for i, item in enumerate(obj):
                    check_operators(item, f"{path}[{i}]")

        check_operators(v)
        return v

# Safe query building
@router.post("/search")
async def search(request: SearchRequest, db = Depends(get_database)):
    # Build query with only allowed fields
    query = {}

    if request.query:
        # Use text search instead of $regex for user input
        query["$text"] = {"$search": request.query}

    # Whitelist allowed filter fields
    ALLOWED_FILTERS = {"status", "category", "created_after"}
    for field, value in request.filters.items():
        if field in ALLOWED_FILTERS:
            # Type-specific handling
            if field == "created_after":
                query["created_at"] = {"$gte": datetime.fromisoformat(value)}
            else:
                query[field] = value

    return await db.items.find(query).to_list(100)
```

---

## 18. SSRF Prevention for URL Parameters

Any endpoint accepting URLs (webhooks, imports, avatars) is an SSRF vector. Allowlist schemes, validate hostnames against internal ranges, and block redirects to internal IPs.

```python
import ipaddress
from urllib.parse import urlparse
import socket

BLOCKED_HOSTS = {"localhost", "127.0.0.1", "0.0.0.0", "metadata.google.internal", "169.254.169.254"}
PRIVATE_RANGES = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
]

async def validate_url_safe(url: str) -> bool:
    """Validate URL doesn't point to internal resources."""
    parsed = urlparse(url)

    # Only allow HTTPS
    if parsed.scheme != "https":
        return False

    hostname = parsed.hostname
    if not hostname:
        return False

    # Block known dangerous hosts
    if hostname.lower() in BLOCKED_HOSTS:
        return False

    # Resolve hostname and check IP
    try:
        ip = ipaddress.ip_address(socket.gethostbyname(hostname))
        for private_range in PRIVATE_RANGES:
            if ip in private_range:
                return False
    except (socket.gaierror, ValueError):
        return False

    return True

@router.post("/webhooks")
async def create_webhook(
    url: str,
    current_user: dict = Depends(get_current_user)
):
    if not await validate_url_safe(url):
        raise HTTPException(400, "Invalid or blocked URL")

    # Safe to store webhook URL
```

---

## 19. GraphQL Query Complexity Limits

Implement depth limiting, complexity scoring, and query cost analysis. A single nested query can explode into millions of database operations.

```python
from graphql import parse, visit, Visitor

MAX_DEPTH = 5
MAX_COMPLEXITY = 100

class ComplexityAnalyzer(Visitor):
    def __init__(self):
        self.depth = 0
        self.max_depth = 0
        self.complexity = 0

        # Cost per field type
        self.field_costs = {
            "users": 10,
            "documents": 5,
            "comments": 2,
            "default": 1
        }

    def enter_field(self, node, *args):
        self.depth += 1
        self.max_depth = max(self.max_depth, self.depth)

        field_name = node.name.value
        self.complexity += self.field_costs.get(field_name, self.field_costs["default"])

    def leave_field(self, node, *args):
        self.depth -= 1

def validate_query_complexity(query: str) -> None:
    """Reject queries that are too deep or complex."""
    ast = parse(query)
    analyzer = ComplexityAnalyzer()
    visit(ast, analyzer)

    if analyzer.max_depth > MAX_DEPTH:
        raise HTTPException(400, f"Query depth {analyzer.max_depth} exceeds limit {MAX_DEPTH}")

    if analyzer.complexity > MAX_COMPLEXITY:
        raise HTTPException(400, f"Query complexity {analyzer.complexity} exceeds limit {MAX_COMPLEXITY}")
```

---

## 20. Prototype Pollution Prevention

In JavaScript-style APIs, recursive object merging can pollute prototypes. Sanitize `__proto__`, `constructor`, and `prototype` keys from all user input.

```python
DANGEROUS_KEYS = {"__proto__", "constructor", "prototype", "__class__", "__bases__", "__subclasses__"}

def sanitize_dict(obj: any, path: str = "") -> any:
    """Recursively remove dangerous keys from nested dicts."""
    if isinstance(obj, dict):
        sanitized = {}
        for key, value in obj.items():
            if key in DANGEROUS_KEYS:
                logger.warning(f"Blocked dangerous key '{key}' at path '{path}'")
                continue
            sanitized[key] = sanitize_dict(value, f"{path}.{key}")
        return sanitized
    elif isinstance(obj, list):
        return [sanitize_dict(item, f"{path}[{i}]") for i, item in enumerate(obj)]
    else:
        return obj

@app.middleware("http")
async def sanitize_request_middleware(request: Request, call_next):
    if request.method in ["POST", "PUT", "PATCH"]:
        body = await request.body()
        if body:
            try:
                data = json.loads(body)
                sanitized = sanitize_dict(data)
                # Replace request body with sanitized version
                request._body = json.dumps(sanitized).encode()
            except json.JSONDecodeError:
                pass

    return await call_next(request)
```

---

## 21. XML External Entity (XXE) Prevention

Disable external entity processing in XML parsers. Default configurations are often vulnerable to XXE attacks that can read local files or make SSRF requests.

```python
from lxml import etree
from defusedxml import ElementTree as DefusedET
import defusedxml

# Use defusedxml for all XML parsing - it's secure by default
def parse_xml_safely(xml_string: str) -> etree.Element:
    """Parse XML with XXE protection."""
    return DefusedET.fromstring(xml_string)

# If you must use lxml directly, configure it securely
def parse_xml_lxml_secure(xml_string: str) -> etree.Element:
    parser = etree.XMLParser(
        resolve_entities=False,
        no_network=True,
        dtd_validation=False,
        load_dtd=False
    )
    return etree.fromstring(xml_string.encode(), parser)

@router.post("/import/xml")
async def import_xml(file: UploadFile):
    content = await file.read()

    try:
        # Safe parsing
        tree = parse_xml_safely(content.decode())
    except defusedxml.DefusedXmlException:
        raise HTTPException(400, "Invalid or dangerous XML")

    # Process tree...
```

---

## 22. Deserialization Attack Prevention

Never deserialize untrusted data with pickle or similar. Use data-only formats (JSON) with explicit schema validation.

```python
# NEVER do this with user input
import pickle
# data = pickle.loads(user_input)  # DANGEROUS!

# Safe approach: use JSON with Pydantic validation
from pydantic import BaseModel

class ImportData(BaseModel):
    version: str
    items: list[dict]
    metadata: dict

@router.post("/import")
async def import_data(file: UploadFile):
    content = await file.read()

    # Only accept JSON
    if not file.content_type == "application/json":
        raise HTTPException(400, "Only JSON format accepted")

    try:
        data = json.loads(content)
        validated = ImportData(**data)  # Schema validation
    except (json.JSONDecodeError, ValidationError) as e:
        raise HTTPException(400, "Invalid data format")

    return await process_import(validated)
```

```python
# If you MUST use pickle (e.g., internal queues), sign payloads
import hmac
import base64

SECRET = os.environ["PICKLE_SIGNING_SECRET"]

def sign_pickle(obj: any) -> str:
    pickled = pickle.dumps(obj)
    signature = hmac.new(SECRET.encode(), pickled, hashlib.sha256).hexdigest()
    return base64.b64encode(pickled).decode() + "." + signature

def verify_and_load_pickle(signed_data: str) -> any:
    try:
        encoded, signature = signed_data.rsplit(".", 1)
        pickled = base64.b64decode(encoded)
        expected_sig = hmac.new(SECRET.encode(), pickled, hashlib.sha256).hexdigest()

        if not hmac.compare_digest(signature, expected_sig):
            raise ValueError("Invalid signature")

        return pickle.loads(pickled)
    except Exception:
        raise ValueError("Invalid signed pickle data")
```

---

## 23. Path Traversal Prevention

`../../../etc/passwd` still works. Canonicalize paths and verify they remain within expected directories after resolution.

```python
import os
from pathlib import Path

UPLOAD_DIR = Path("/app/uploads").resolve()

def safe_join_path(base: Path, user_path: str) -> Path:
    """Safely join user-provided path component, preventing traversal."""
    # Remove any leading slashes or dots
    clean_path = user_path.lstrip("/").lstrip(".")

    # Join and resolve to absolute path
    full_path = (base / clean_path).resolve()

    # Verify result is still under base directory
    if not str(full_path).startswith(str(base)):
        raise ValueError("Path traversal detected")

    return full_path

@router.get("/files/{file_path:path}")
async def get_file(file_path: str, current_user: dict = Depends(get_current_user)):
    try:
        safe_path = safe_join_path(UPLOAD_DIR / str(current_user["_id"]), file_path)
    except ValueError:
        raise HTTPException(403, "Access denied")

    if not safe_path.exists():
        raise HTTPException(404, "File not found")

    return FileResponse(safe_path)
```

---

## 24. Content-Type Enforcement

Validate that request Content-Type matches what you expect. Attackers send JSON to XML endpoints to trigger parser confusion and bypass validation.

```python
from fastapi import Header

async def require_json_content_type(content_type: str = Header(...)):
    """Enforce JSON content type for API requests."""
    if not content_type.startswith("application/json"):
        raise HTTPException(
            415,
            "Unsupported Media Type. Expected application/json"
        )

@router.post("/api/data", dependencies=[Depends(require_json_content_type)])
async def create_data(data: DataRequest):
    # Only reaches here if Content-Type is application/json
    pass
```

```python
# Global middleware for stricter enforcement
@app.middleware("http")
async def validate_content_type(request: Request, call_next):
    if request.method in ["POST", "PUT", "PATCH"]:
        content_type = request.headers.get("content-type", "")

        # API routes require JSON
        if request.url.path.startswith("/api/"):
            if not content_type.startswith("application/json"):
                return JSONResponse(
                    status_code=415,
                    content={"detail": "Content-Type must be application/json"}
                )

    return await call_next(request)
```

---

# Rate Limiting & Abuse Prevention

## 25. Multi-Dimensional Rate Limiting

IP alone is insufficient (NAT, proxies, cloud egress). Layer user-based, API key-based, and IP-based limits with different thresholds for different protection goals.

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

def get_rate_limit_key(request: Request) -> str:
    """Generate composite rate limit key."""
    parts = []

    # Layer 1: IP (catches unauthenticated abuse)
    ip = get_remote_address(request)
    parts.append(f"ip:{ip}")

    # Layer 2: User ID if authenticated
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    if token:
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            parts.append(f"user:{payload.get('sub')}")
        except:
            pass

    # Layer 3: API key if present
    api_key = request.headers.get("X-API-Key", "")
    if api_key:
        parts.append(f"key:{api_key[:16]}")

    return ":".join(parts)

limiter = Limiter(key_func=get_rate_limit_key)

# Different limits for different contexts
@router.post("/api/generate")
@limiter.limit("10/minute", key_func=lambda r: f"user:{get_user_id(r)}")  # Per user
@limiter.limit("100/minute", key_func=get_remote_address)  # Per IP
@limiter.limit("1000/hour", key_func=lambda r: f"key:{get_api_key(r)}")  # Per API key
async def generate_content(request: GenerateRequest):
    pass
```

---

## 26. Atomic Rate Limit Checks

Implement atomic increment-and-check. Non-atomic read-then-write lets parallel requests slip through the limit.

```python
import aioredis

async def check_rate_limit(
    key: str,
    limit: int,
    window_seconds: int,
    redis: aioredis.Redis
) -> tuple[bool, int]:
    """
    Atomic rate limit check using Redis INCR.
    Returns (allowed, remaining).
    """
    pipe = redis.pipeline()

    # Atomic increment
    pipe.incr(key)
    pipe.expire(key, window_seconds)

    results = await pipe.execute()
    current_count = results[0]

    allowed = current_count <= limit
    remaining = max(0, limit - current_count)

    return allowed, remaining

# Using Lua script for even more complex atomic operations
RATE_LIMIT_SCRIPT = """
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])

local current = redis.call('INCR', key)
if current == 1 then
    redis.call('EXPIRE', key, window)
end

if current > limit then
    return {0, 0, redis.call('TTL', key)}
else
    return {1, limit - current, redis.call('TTL', key)}
end
"""

async def atomic_rate_limit(redis, key: str, limit: int, window: int):
    result = await redis.eval(RATE_LIMIT_SCRIPT, 1, key, limit, window)
    allowed, remaining, reset_in = result
    return bool(allowed), remaining, reset_in
```

---

## 27. Cost-Based Rate Limiting

Expensive operations (reports, exports, AI inference) need separate, stricter limits than cheap reads. One heavy endpoint can DoS your system under normal rate limits.

```python
# Define operation costs
OPERATION_COSTS = {
    "list_documents": 1,
    "get_document": 1,
    "create_document": 5,
    "export_documents": 50,
    "generate_ai_content": 100,
    "generate_report": 200,
}

# Per-user cost budget per hour
HOURLY_COST_BUDGET = 1000

async def check_cost_budget(
    user_id: str,
    operation: str,
    redis: aioredis.Redis
) -> bool:
    """Check if user has budget for this operation."""
    cost = OPERATION_COSTS.get(operation, 10)
    key = f"cost_budget:{user_id}:{datetime.utcnow().strftime('%Y%m%d%H')}"

    current = await redis.incrby(key, cost)
    if current == cost:  # First operation this hour
        await redis.expire(key, 3600)

    if current > HOURLY_COST_BUDGET:
        return False

    return True

@router.post("/generate")
async def generate_content(
    request: GenerateRequest,
    current_user: dict = Depends(get_current_user),
    redis = Depends(get_redis)
):
    if not await check_cost_budget(str(current_user["_id"]), "generate_ai_content", redis):
        raise HTTPException(429, "Hourly cost budget exceeded")

    # Proceed with expensive operation...
```

---

## 28. X-Forwarded-For Spoofing Prevention

Don't trust client-supplied headers for rate limiting. Only use XFF from trusted proxies in your infrastructure.

```python
from typing import List

# List of trusted proxy IPs (your load balancers, CDN)
TRUSTED_PROXIES: List[str] = [
    "10.0.0.0/8",  # Internal network
    # Add your CDN IP ranges
]

def get_real_client_ip(request: Request) -> str:
    """Extract real client IP, only trusting known proxies."""
    client_ip = request.client.host

    # Check if direct connection is from trusted proxy
    if not is_trusted_proxy(client_ip):
        return client_ip  # Don't trust XFF from untrusted sources

    # Parse X-Forwarded-For from right to left, stopping at first untrusted IP
    xff = request.headers.get("X-Forwarded-For", "")
    if xff:
        ips = [ip.strip() for ip in xff.split(",")]

        # Walk backwards through the chain
        for ip in reversed(ips):
            if not is_trusted_proxy(ip):
                return ip  # First untrusted IP is the real client

    return client_ip

def is_trusted_proxy(ip: str) -> bool:
    """Check if IP is in our trusted proxy list."""
    try:
        addr = ipaddress.ip_address(ip)
        for proxy_range in TRUSTED_PROXIES:
            if addr in ipaddress.ip_network(proxy_range):
                return True
    except ValueError:
        pass
    return False
```

---

## 29. Retry-After Headers

Return them with 429 responses. Well-behaved clients back off; you've documented which don't for anomaly detection.

```python
from fastapi.responses import JSONResponse

class RateLimitExceeded(Exception):
    def __init__(self, reset_time: int, limit: int, remaining: int = 0):
        self.reset_time = reset_time
        self.limit = limit
        self.remaining = remaining

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={
            "detail": "Rate limit exceeded",
            "retry_after": exc.reset_time
        },
        headers={
            "Retry-After": str(exc.reset_time),
            "X-RateLimit-Limit": str(exc.limit),
            "X-RateLimit-Remaining": "0",
            "X-RateLimit-Reset": str(int(datetime.utcnow().timestamp()) + exc.reset_time)
        }
    )

# Include rate limit headers on successful responses too
@app.middleware("http")
async def add_rate_limit_headers(request: Request, call_next):
    response = await call_next(request)

    # Get current rate limit status from Redis
    user_id = get_user_id_from_request(request)
    if user_id:
        remaining, reset = await get_rate_limit_status(user_id)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset)

    return response
```

---

## 30. Credential Stuffing Protection

Rate limit by (IP, username) tuple, not just IP. Slow rotation through usernames evades per-IP limits.

```python
async def check_login_rate_limits(
    email: str,
    ip: str,
    redis: aioredis.Redis
) -> None:
    """Multi-factor rate limiting for login attempts."""

    # 1. Per-IP limit (general abuse)
    ip_key = f"login:ip:{ip}"
    ip_count = await redis.incr(ip_key)
    if ip_count == 1:
        await redis.expire(ip_key, 900)  # 15 min window
    if ip_count > 20:
        raise HTTPException(429, "Too many login attempts from this IP")

    # 2. Per-email limit (targeted attack on specific account)
    email_key = f"login:email:{hashlib.sha256(email.encode()).hexdigest()}"
    email_count = await redis.incr(email_key)
    if email_count == 1:
        await redis.expire(email_key, 900)
    if email_count > 5:
        raise HTTPException(429, "Too many login attempts for this account")

    # 3. Per IP+email combo (credential stuffing detection)
    combo_key = f"login:combo:{ip}:{hashlib.sha256(email.encode()).hexdigest()}"
    combo_count = await redis.incr(combo_key)
    if combo_count == 1:
        await redis.expire(combo_key, 3600)  # 1 hour
    if combo_count > 3:
        # Log for security review - likely credential stuffing
        logger.warning(f"Possible credential stuffing: IP={ip}, email_hash={email_key}")
        raise HTTPException(429, "Suspicious login pattern detected")

@router.post("/auth/login")
async def login(credentials: LoginRequest, request: Request, redis = Depends(get_redis)):
    await check_login_rate_limits(
        credentials.email,
        get_real_client_ip(request),
        redis
    )
    # Proceed with authentication...
```

---

# Data Exposure & Information Leakage

## 31. Verbose Error Suppression

Stack traces, SQL queries, and internal paths in error responses are reconnaissance gold. Return generic errors externally, log details internally.

```python
import logging
import traceback

logger = logging.getLogger(__name__)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # Generate unique error ID for correlation
    error_id = secrets.token_hex(8)

    # Log full details internally
    logger.error(
        f"Unhandled exception [{error_id}]: {exc}\n"
        f"Path: {request.url.path}\n"
        f"Traceback: {traceback.format_exc()}"
    )

    # Return minimal info externally
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An internal error occurred",
            "error_id": error_id  # For support correlation
        }
    )

# Specific handler for validation errors - safe to expose
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Sanitize validation errors to avoid leaking internal field names
    safe_errors = []
    for error in exc.errors():
        safe_errors.append({
            "field": error["loc"][-1] if error["loc"] else "unknown",
            "message": error["msg"]
        })

    return JSONResponse(
        status_code=422,
        content={"detail": "Validation error", "errors": safe_errors}
    )
```

---

## 32. Debug Endpoint Protection

`/debug`, `/actuator`, `/metrics`, `/graphql/playground`—audit for these. They ship enabled by default in many frameworks.

```python
import os

# Only enable debug routes in development
if os.environ.get("ENVIRONMENT") != "production":
    from fastapi_debug_toolbar import DebugToolbarMiddleware
    app.add_middleware(DebugToolbarMiddleware)

    @router.get("/debug/routes")
    async def list_routes():
        return [{"path": r.path, "methods": r.methods} for r in app.routes]
else:
    # In production, explicitly block debug paths
    DEBUG_PATHS = ["/debug", "/actuator", "/_debug", "/graphql/playground", "/docs", "/redoc"]

    @app.middleware("http")
    async def block_debug_paths(request: Request, call_next):
        for path in DEBUG_PATHS:
            if request.url.path.startswith(path):
                raise HTTPException(404, "Not found")
        return await call_next(request)

# If you must expose /docs in production, add auth
@router.get("/docs", include_in_schema=False)
async def custom_swagger_ui(admin: dict = Depends(require_roles(["admin"]))):
    return get_swagger_ui_html(openapi_url="/openapi.json", title="API Docs")
```

---

## 33. GraphQL Introspection Control

Disable introspection in production. It's a complete schema map for attackers showing every type, field, and relationship.

```python
from ariadne import make_executable_schema
from ariadne.asgi import GraphQL

# Development: introspection enabled
if os.environ.get("ENVIRONMENT") != "production":
    graphql_app = GraphQL(schema, debug=True)
else:
    # Production: disable introspection
    graphql_app = GraphQL(
        schema,
        debug=False,
        introspection=False
    )

# Or with Strawberry
import strawberry
from strawberry.extensions import DisableValidation

@strawberry.type
class Query:
    @strawberry.field
    def hello(self) -> str:
        return "world"

schema = strawberry.Schema(
    query=Query,
    extensions=[
        # Custom extension to block introspection
    ]
)

# Middleware approach - block introspection queries
@app.middleware("http")
async def block_introspection(request: Request, call_next):
    if request.url.path == "/graphql" and request.method == "POST":
        body = await request.body()
        if b"__schema" in body or b"__type" in body:
            if os.environ.get("ENVIRONMENT") == "production":
                return JSONResponse(
                    status_code=400,
                    content={"errors": [{"message": "Introspection disabled"}]}
                )
    return await call_next(request)
```

---

## 34. API Version Security

Old API versions often lack newer security controls. Deprecate aggressively. Each version is additional attack surface.

```python
from datetime import datetime
from packaging import version

# Version deprecation registry
API_VERSIONS = {
    "v1": {"deprecated": True, "sunset": "2024-01-01", "security_level": "legacy"},
    "v2": {"deprecated": True, "sunset": "2024-06-01", "security_level": "standard"},
    "v3": {"deprecated": False, "sunset": None, "security_level": "current"},
}

@app.middleware("http")
async def version_security_middleware(request: Request, call_next):
    # Extract version from path (e.g., /api/v1/users)
    path_parts = request.url.path.split("/")
    api_version = next((p for p in path_parts if p.startswith("v")), "v3")

    version_info = API_VERSIONS.get(api_version)

    if not version_info:
        raise HTTPException(400, "Invalid API version")

    # Block sunset versions
    if version_info.get("sunset"):
        sunset_date = datetime.fromisoformat(version_info["sunset"])
        if datetime.utcnow() > sunset_date:
            raise HTTPException(
                410,
                f"API {api_version} has been sunset. Please upgrade to v3."
            )

    # Add deprecation warning headers
    response = await call_next(request)

    if version_info.get("deprecated"):
        response.headers["Deprecation"] = "true"
        response.headers["Sunset"] = version_info.get("sunset", "")
        response.headers["Link"] = '</api/v3>; rel="successor-version"'

    return response
```

---

## 35. Sensitive Data in URLs

Query parameters appear in logs, browser history, referrer headers, and CDN caches. Use POST bodies or headers for tokens, credentials, and PII.

```python
# BAD: Token in URL
@router.get("/reset-password")  # /reset-password?token=abc123
async def reset_password(token: str):
    pass

# GOOD: Token in POST body
class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str

@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest):
    pass

# Middleware to detect and warn about sensitive data in URLs
SENSITIVE_PARAMS = {"token", "password", "secret", "api_key", "credit_card", "ssn"}

@app.middleware("http")
async def check_sensitive_query_params(request: Request, call_next):
    found_sensitive = set(request.query_params.keys()) & SENSITIVE_PARAMS

    if found_sensitive:
        logger.warning(
            f"Sensitive data in URL: {found_sensitive} - Path: {request.url.path}"
        )
        # In strict mode, reject the request
        if os.environ.get("STRICT_SECURITY") == "true":
            raise HTTPException(400, "Sensitive data must not be sent in URL")

    return await call_next(request)
```

---

## 36. Response Field Filtering

Return only necessary fields. Over-fetching exposes internal IDs, timestamps, and metadata that aid enumeration and reveal system internals.

```python
from pydantic import BaseModel
from typing import Optional

# Internal model (what's in MongoDB)
class UserDocument:
    id: ObjectId
    email: str
    name: str
    password_hash: str
    internal_notes: str
    created_ip: str
    last_login_ip: str
    failed_login_count: int
    subscription_internal_id: str

# Public response (what API returns)
class UserPublicResponse(BaseModel):
    id: str
    name: str

    class Config:
        extra = "forbid"  # Prevent accidental field leakage

# Authenticated user's own profile
class UserSelfResponse(BaseModel):
    id: str
    email: str
    name: str
    created_at: datetime

    class Config:
        extra = "forbid"

# Admin view
class UserAdminResponse(BaseModel):
    id: str
    email: str
    name: str
    created_at: datetime
    last_login_at: Optional[datetime]
    subscription_status: str
    # Still excludes: password_hash, internal_notes, IPs

@router.get("/users/{user_id}")
async def get_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    user = await db.users.find_one({"_id": ObjectId(user_id)})

    if str(current_user["_id"]) == user_id:
        return UserSelfResponse(**user)
    elif current_user.get("role") == "admin":
        return UserAdminResponse(**user)
    else:
        return UserPublicResponse(**user)
```

---

## 37. CORS Configuration Security

`Access-Control-Allow-Origin: *` with credentials is dangerous. Reflect origins dynamically only from an explicit allowlist.

```python
from fastapi.middleware.cors import CORSMiddleware

# NEVER do this
# app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True)

# Explicit allowlist
ALLOWED_ORIGINS = [
    "https://app.example.com",
    "https://admin.example.com",
]

if os.environ.get("ENVIRONMENT") == "development":
    ALLOWED_ORIGINS.append("http://localhost:3000")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["X-RateLimit-Remaining", "X-RateLimit-Reset"],
    max_age=600,
)
```

```python
# For dynamic origin validation (multi-tenant)
from starlette.middleware.base import BaseHTTPMiddleware

class DynamicCORSMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        origin = request.headers.get("origin")

        # Validate origin against database of allowed tenant domains
        if origin and await is_valid_tenant_origin(origin):
            response = await call_next(request)
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Access-Control-Allow-Credentials"] = "true"
            return response

        return await call_next(request)
```

---

## 38. Server Header Stripping

Remove `Server`, `X-Powered-By`, and version headers. They're fingerprinting aids with zero legitimate value.

```python
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)

    # Remove identifying headers
    headers_to_remove = ["Server", "X-Powered-By", "X-AspNet-Version"]
    for header in headers_to_remove:
        if header in response.headers:
            del response.headers[header]

    # Add security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"

    if request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    return response

# Configure uvicorn to not send Server header
# uvicorn main:app --header "Server:"
```

---

# Cryptography & Secrets Management

## 39. Secret Management Architecture

Better than code or env vars on disk, secrets persist in process listings and crash dumps. Use secret managers with short-lived credentials.

```python
from functools import lru_cache
import boto3
from google.cloud import secretmanager

class SecretManager:
    """Centralized secret management with caching and rotation support."""

    def __init__(self):
        self.client = secretmanager.SecretManagerServiceClient()
        self.project_id = os.environ["GCP_PROJECT_ID"]
        self._cache = {}
        self._cache_expiry = {}

    async def get_secret(self, secret_name: str, max_age: int = 300) -> str:
        """Get secret with TTL-based caching."""
        now = datetime.utcnow().timestamp()

        # Check cache
        if secret_name in self._cache:
            if now < self._cache_expiry.get(secret_name, 0):
                return self._cache[secret_name]

        # Fetch from secret manager
        name = f"projects/{self.project_id}/secrets/{secret_name}/versions/latest"
        response = self.client.access_secret_version(request={"name": name})
        secret_value = response.payload.data.decode("UTF-8")

        # Cache with expiry
        self._cache[secret_name] = secret_value
        self._cache_expiry[secret_name] = now + max_age

        return secret_value

secrets = SecretManager()

# Usage in dependencies
async def get_jwt_secret() -> str:
    return await secrets.get_secret("jwt-signing-key")

async def get_db_connection_string() -> str:
    return await secrets.get_secret("mongodb-connection-string", max_age=60)
```

---

## 40. API Key Generation and Management

256 bits minimum for keys that grant access. Prefix keys for easy scanning and rotation.

```python
import secrets
import hashlib
from datetime import datetime

def generate_api_key(key_type: str = "live") -> tuple[str, str]:
    """
    Generate API key with prefix and hash.
    Returns (display_key, hash_for_storage).
    """
    # Prefix for easy identification: sk_live_, sk_test_, pk_
    prefix = f"sk_{key_type}_"

    # 32 bytes = 256 bits of randomness
    random_part = secrets.token_urlsafe(32)

    full_key = f"{prefix}{random_part}"

    # Store hash, not the actual key
    key_hash = hashlib.sha256(full_key.encode()).hexdigest()

    return full_key, key_hash

async def create_api_key(
    user_id: str,
    name: str,
    permissions: list[str],
    db
) -> dict:
    display_key, key_hash = generate_api_key()

    await db.api_keys.insert_one({
        "user_id": ObjectId(user_id),
        "name": name,
        "key_prefix": display_key[:12],  # For identification without exposing full key
        "key_hash": key_hash,
        "permissions": permissions,
        "created_at": datetime.utcnow(),
        "last_used_at": None,
        "revoked": False
    })

    # Return full key only once - user must save it
    return {
        "key": display_key,
        "prefix": display_key[:12],
        "message": "Save this key now. It won't be shown again."
    }

async def verify_api_key(api_key: str, db) -> dict:
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()

    key_doc = await db.api_keys.find_one({
        "key_hash": key_hash,
        "revoked": False
    })

    if not key_doc:
        raise HTTPException(401, "Invalid API key")

    # Update last used
    await db.api_keys.update_one(
        {"_id": key_doc["_id"]},
        {"$set": {"last_used_at": datetime.utcnow()}}
    )

    return key_doc
```

---

## 41. Key Rotation Architecture

Build rotation capability from day one. Support multiple active keys during transition windows to avoid breaking clients.

```python
from typing import List
from datetime import datetime, timedelta

class KeyRotationManager:
    def __init__(self, db, redis):
        self.db = db
        self.redis = redis

    async def get_active_signing_keys(self) -> List[dict]:
        """Get all currently valid signing keys (for verification)."""
        return await self.db.signing_keys.find({
            "status": {"$in": ["active", "rotating_out"]},
            "$or": [
                {"expires_at": {"$gt": datetime.utcnow()}},
                {"expires_at": None}
            ]
        }).to_list(10)

    async def get_primary_signing_key(self) -> dict:
        """Get the primary key for new signatures."""
        return await self.db.signing_keys.find_one({
            "status": "active",
            "primary": True
        })

    async def rotate_key(self, new_key: str, transition_period_hours: int = 24):
        """Rotate to new key with transition period."""
        now = datetime.utcnow()

        # Mark current primary as rotating out
        await self.db.signing_keys.update_one(
            {"primary": True, "status": "active"},
            {
                "$set": {
                    "status": "rotating_out",
                    "primary": False,
                    "expires_at": now + timedelta(hours=transition_period_hours)
                }
            }
        )

        # Add new primary key
        await self.db.signing_keys.insert_one({
            "key": new_key,
            "key_id": secrets.token_hex(8),
            "status": "active",
            "primary": True,
            "created_at": now,
            "expires_at": None
        })

        # Clear key cache
        await self.redis.delete("signing_keys_cache")

# JWT signing with key ID for rotation support
def create_token_with_kid(payload: dict, key_manager: KeyRotationManager) -> str:
    key = await key_manager.get_primary_signing_key()

    headers = {"kid": key["key_id"]}  # Key ID for verification
    return jwt.encode(payload, key["key"], algorithm="HS256", headers=headers)

def verify_token_with_kid(token: str, key_manager: KeyRotationManager) -> dict:
    # Get key ID from header
    unverified = jwt.get_unverified_header(token)
    kid = unverified.get("kid")

    # Find matching key
    keys = await key_manager.get_active_signing_keys()
    key = next((k for k in keys if k["key_id"] == kid), None)

    if not key:
        raise HTTPException(401, "Invalid token - unknown key")

    return jwt.decode(token, key["key"], algorithms=["HS256"])
```

---

## 42. Field-Level Encryption

Database-level encryption doesn't protect against SQL injection or compromised app servers. Field-level encryption with application-held keys does.

```python
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

class FieldEncryption:
    def __init__(self, master_key: str):
        # Derive encryption key from master key
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=b"field_encryption_salt",  # Use unique salt per deployment
            iterations=100000,
        )
        key = base64.urlsafe_b64encode(kdf.derive(master_key.encode()))
        self.cipher = Fernet(key)

    def encrypt(self, plaintext: str) -> str:
        """Encrypt a field value."""
        return self.cipher.encrypt(plaintext.encode()).decode()

    def decrypt(self, ciphertext: str) -> str:
        """Decrypt a field value."""
        return self.cipher.decrypt(ciphertext.encode()).decode()

field_crypto = FieldEncryption(os.environ["FIELD_ENCRYPTION_KEY"])

# Pydantic model with encrypted fields
class UserCreate(BaseModel):
    email: str
    ssn: str  # Sensitive - will be encrypted

    def to_document(self) -> dict:
        return {
            "email": self.email,
            "ssn_encrypted": field_crypto.encrypt(self.ssn),
        }

class UserResponse(BaseModel):
    email: str
    ssn_masked: str  # Only show last 4

    @classmethod
    def from_document(cls, doc: dict) -> "UserResponse":
        ssn = field_crypto.decrypt(doc["ssn_encrypted"])
        return cls(
            email=doc["email"],
            ssn_masked=f"***-**-{ssn[-4:]}"
        )
```

---

# Logging, Monitoring & Incident Response

## 43. Log Injection Prevention

User input in logs can inject fake entries or corrupt log formats. Sanitize or encode user data before logging.

```python
import re
import json

def sanitize_for_logging(value: any) -> str:
    """Sanitize value for safe logging."""
    if value is None:
        return "null"

    s = str(value)

    # Remove newlines and control characters (prevent log injection)
    s = re.sub(r'[\r\n\x00-\x1f\x7f-\x9f]', ' ', s)

    # Truncate long values
    if len(s) > 500:
        s = s[:500] + "...[truncated]"

    return s

def log_request_safely(logger, request: Request, extra: dict = None):
    """Log request with sanitized user input."""
    safe_extra = {
        "path": sanitize_for_logging(request.url.path),
        "method": request.method,
        "user_agent": sanitize_for_logging(request.headers.get("user-agent", "")),
        "client_ip": request.client.host,
    }

    if extra:
        for key, value in extra.items():
            safe_extra[key] = sanitize_for_logging(value)

    logger.info("Request processed", extra=safe_extra)

# Structured logging prevents injection better than string formatting
import structlog

logger = structlog.get_logger()

@app.middleware("http")
async def structured_logging_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)

    # Structured log entry - values are escaped by the JSON formatter
    logger.info(
        "request_completed",
        path=request.url.path,
        method=request.method,
        status=response.status_code,
        duration_ms=int((time.time() - start_time) * 1000),
        user_agent=request.headers.get("user-agent"),
    )

    return response
```

---

## 44. Sensitive Data Redaction in Logs

Audit what you log. Request bodies, headers, and error contexts often contain credentials, tokens, and PII.

```python
import re
from copy import deepcopy

SENSITIVE_PATTERNS = [
    (re.compile(r'password["\s:=]+["\']?[\w@#$%^&*]+["\']?', re.I), 'password=***'),
    (re.compile(r'token["\s:=]+["\']?[\w\-_.]+["\']?', re.I), 'token=***'),
    (re.compile(r'Bearer\s+[\w\-_.]+', re.I), 'Bearer ***'),
    (re.compile(r'api[_-]?key["\s:=]+["\']?[\w\-]+["\']?', re.I), 'api_key=***'),
    (re.compile(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b'), '****-****-****-****'),  # Credit card
    (re.compile(r'\b\d{3}[- ]?\d{2}[- ]?\d{4}\b'), '***-**-****'),  # SSN
]

SENSITIVE_FIELDS = {"password", "token", "api_key", "secret", "credit_card", "ssn", "authorization"}

def redact_sensitive_string(text: str) -> str:
    """Redact sensitive patterns from a string."""
    result = text
    for pattern, replacement in SENSITIVE_PATTERNS:
        result = pattern.sub(replacement, result)
    return result

def redact_sensitive_dict(data: dict) -> dict:
    """Recursively redact sensitive fields from a dictionary."""
    if not isinstance(data, dict):
        return data

    result = {}
    for key, value in data.items():
        if key.lower() in SENSITIVE_FIELDS:
            result[key] = "***REDACTED***"
        elif isinstance(value, dict):
            result[key] = redact_sensitive_dict(value)
        elif isinstance(value, list):
            result[key] = [redact_sensitive_dict(item) if isinstance(item, dict) else item for item in value]
        elif isinstance(value, str):
            result[key] = redact_sensitive_string(value)
        else:
            result[key] = value

    return result

# Usage in request logging
@app.middleware("http")
async def safe_request_logging(request: Request, call_next):
    # Safely log request
    body = await request.body()
    if body:
        try:
            body_dict = json.loads(body)
            safe_body = redact_sensitive_dict(body_dict)
            logger.debug("Request body", body=safe_body)
        except:
            pass

    return await call_next(request)
```

---

## 45. Anomaly Detection Baselines

Establish normal traffic patterns. Alert on statistical deviations—spike in 4xx errors, unusual endpoint access sequences, geographic anomalies.

```python
from collections import defaultdict
from datetime import datetime, timedelta
import statistics

class AnomalyDetector:
    def __init__(self, redis):
        self.redis = redis
        self.alert_threshold = 3  # Standard deviations

    async def record_metric(self, metric_name: str, value: float):
        """Record a metric value for anomaly detection."""
        now = datetime.utcnow()
        key = f"metrics:{metric_name}:{now.strftime('%Y%m%d%H')}"

        await self.redis.lpush(key, value)
        await self.redis.expire(key, 86400 * 7)  # Keep 7 days

    async def check_anomaly(self, metric_name: str, current_value: float) -> bool:
        """Check if current value is anomalous based on historical data."""
        # Get last 24 hours of data
        now = datetime.utcnow()
        values = []

        for i in range(24):
            hour = now - timedelta(hours=i)
            key = f"metrics:{metric_name}:{hour.strftime('%Y%m%d%H')}"
            hour_values = await self.redis.lrange(key, 0, -1)
            values.extend([float(v) for v in hour_values])

        if len(values) < 10:
            return False  # Not enough data

        mean = statistics.mean(values)
        stdev = statistics.stdev(values)

        if stdev == 0:
            return current_value != mean

        z_score = abs(current_value - mean) / stdev
        return z_score > self.alert_threshold

# Usage in middleware
detector = AnomalyDetector(redis)

@app.middleware("http")
async def anomaly_detection_middleware(request: Request, call_next):
    response = await call_next(request)

    # Track error rates
    if response.status_code >= 400:
        await detector.record_metric(f"errors:{request.url.path}", 1)

        # Check for anomalous error rate
        recent_errors = await detector.redis.incr(f"error_count:{request.url.path}:5min")
        if recent_errors == 1:
            await detector.redis.expire(f"error_count:{request.url.path}:5min", 300)

        if await detector.check_anomaly(f"errors:{request.url.path}", recent_errors):
            logger.warning(
                "Anomalous error rate detected",
                path=request.url.path,
                error_count=recent_errors
            )

    return response
```

---

## 46. Honeypot Endpoints

Deploy fake admin endpoints and API keys. Any access is definitionally malicious and high-signal.

```python
import secrets

# Generate honeypot tokens at startup
HONEYPOT_TOKENS = [secrets.token_urlsafe(32) for _ in range(10)]
HONEYPOT_API_KEYS = [f"sk_live_{secrets.token_urlsafe(32)}" for _ in range(10)]

# Honeypot routes - any access is suspicious
@router.get("/admin/config", include_in_schema=False)
@router.get("/api/v1/internal/users", include_in_schema=False)
@router.get("/.env", include_in_schema=False)
@router.get("/wp-admin", include_in_schema=False)
async def honeypot_endpoint(request: Request):
    """Honeypot - log and alert on any access."""
    logger.critical(
        "HONEYPOT TRIGGERED",
        extra={
            "alert_type": "honeypot",
            "path": request.url.path,
            "ip": request.client.host,
            "headers": dict(request.headers),
            "severity": "critical"
        }
    )

    # Add IP to watchlist
    await redis.sadd("suspicious_ips", request.client.host)
    await redis.expire("suspicious_ips", 86400)

    # Return realistic-looking error after delay (waste attacker's time)
    await asyncio.sleep(2)
    raise HTTPException(403, "Access denied")

# Check for honeypot token usage
async def check_honeypot_token(authorization: str = Header(None)):
    if authorization:
        token = authorization.replace("Bearer ", "")
        if token in HONEYPOT_TOKENS:
            logger.critical("Honeypot token used", extra={"token_prefix": token[:16]})
            raise HTTPException(401, "Invalid token")

# Inject honeypot detection into all routes
app.dependency_overrides[verify_jwt_token] = lambda: Depends(check_honeypot_token)
```

---

## 47. Audit Trail Integrity

Append-only logging with cryptographic chaining or external SIEM storage. Attackers who gain access will try to cover tracks.

```python
import hashlib
from datetime import datetime

class ImmutableAuditLog:
    """Append-only audit log with cryptographic integrity verification."""

    def __init__(self, db):
        self.db = db
        self.collection = db.audit_log

    async def get_last_hash(self) -> str:
        """Get hash of last audit entry for chaining."""
        last = await self.collection.find_one(
            sort=[("sequence", -1)]
        )
        return last["entry_hash"] if last else "genesis"

    async def log(self, action: str, actor: str, resource: str, details: dict = None):
        """Create immutable audit log entry."""
        previous_hash = await self.get_last_hash()

        entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "action": action,
            "actor": actor,
            "resource": resource,
            "details": details or {},
            "previous_hash": previous_hash,
        }

        # Create hash of entry (includes previous hash for chaining)
        entry_string = json.dumps(entry, sort_keys=True)
        entry["entry_hash"] = hashlib.sha256(entry_string.encode()).hexdigest()

        # Get next sequence number atomically
        counter = await self.db.counters.find_one_and_update(
            {"_id": "audit_sequence"},
            {"$inc": {"value": 1}},
            upsert=True,
            return_document=True
        )
        entry["sequence"] = counter["value"]

        await self.collection.insert_one(entry)

        return entry

    async def verify_integrity(self) -> tuple[bool, int]:
        """Verify the entire audit chain hasn't been tampered with."""
        cursor = self.collection.find().sort("sequence", 1)

        previous_hash = "genesis"
        count = 0

        async for entry in cursor:
            # Verify previous hash matches
            if entry["previous_hash"] != previous_hash:
                return False, count

            # Verify entry hash
            entry_copy = {k: v for k, v in entry.items() if k not in ["_id", "entry_hash", "sequence"]}
            expected_hash = hashlib.sha256(
                json.dumps(entry_copy, sort_keys=True).encode()
            ).hexdigest()

            if entry["entry_hash"] != expected_hash:
                return False, count

            previous_hash = entry["entry_hash"]
            count += 1

        return True, count

# Usage
audit = ImmutableAuditLog(db)

@router.delete("/users/{user_id}")
async def delete_user(user_id: str, current_user: dict = Depends(get_current_user)):
    await audit.log(
        action="user.delete",
        actor=str(current_user["_id"]),
        resource=f"user:{user_id}",
        details={"deleted_by_role": current_user.get("role")}
    )

    await db.users.delete_one({"_id": ObjectId(user_id)})
```

---

# Business Logic & Semantic Security

## 48. TOCTOU Prevention in Workflows

Time-of-check-time-of-use bugs appear when you validate then act non-atomically. Verify permissions at the moment of action, within transactions.

```python
from motor.motor_asyncio import AsyncIOMotorClient

async def transfer_credits(
    from_user_id: str,
    to_user_id: str,
    amount: int,
    db: AsyncIOMotorClient
):
    """Atomic credit transfer preventing TOCTOU race conditions."""

    async with await db.client.start_session() as session:
        async with session.start_transaction():
            # Check and debit atomically
            result = await db.users.update_one(
                {
                    "_id": ObjectId(from_user_id),
                    "credits": {"$gte": amount}  # Check within update
                },
                {"$inc": {"credits": -amount}},
                session=session
            )

            if result.modified_count == 0:
                raise HTTPException(400, "Insufficient credits")

            # Credit recipient
            await db.users.update_one(
                {"_id": ObjectId(to_user_id)},
                {"$inc": {"credits": amount}},
                session=session
            )

            # Log transaction
            await db.transactions.insert_one({
                "from": ObjectId(from_user_id),
                "to": ObjectId(to_user_id),
                "amount": amount,
                "timestamp": datetime.utcnow()
            }, session=session)
```

```python
# Inventory reservation with atomic check
async def reserve_inventory(product_id: str, quantity: int, user_id: str, db):
    """Reserve inventory atomically to prevent overselling."""

    result = await db.products.update_one(
        {
            "_id": ObjectId(product_id),
            "available_quantity": {"$gte": quantity}  # Check in query
        },
        {
            "$inc": {"available_quantity": -quantity},
            "$push": {
                "reservations": {
                    "user_id": ObjectId(user_id),
                    "quantity": quantity,
                    "expires_at": datetime.utcnow() + timedelta(minutes=15),
                    "reservation_id": ObjectId()
                }
            }
        }
    )

    if result.modified_count == 0:
        raise HTTPException(400, "Insufficient inventory")

    return True
```

---

## 49. Negative Value and Boundary Handling

Test negative quantities, zero prices, integer overflow amounts, and currency edge cases. Business logic rarely handles these correctly.

```python
from pydantic import BaseModel, validator, Field
from decimal import Decimal, ROUND_HALF_UP
import sys

class OrderItem(BaseModel):
    product_id: str
    quantity: int = Field(..., gt=0, le=1000)  # Positive, reasonable max
    unit_price: Decimal = Field(..., gt=0, le=Decimal("999999.99"))

    @validator("quantity")
    def validate_quantity(cls, v):
        if v <= 0:
            raise ValueError("Quantity must be positive")
        if v > 1000:
            raise ValueError("Quantity exceeds maximum")
        return v

    @validator("unit_price")
    def validate_price(cls, v):
        if v <= 0:
            raise ValueError("Price must be positive")
        # Ensure 2 decimal places
        return v.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

class PaymentRequest(BaseModel):
    amount: Decimal = Field(..., gt=0)
    currency: str = Field(..., pattern="^[A-Z]{3}$")

    @validator("amount")
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError("Amount must be positive")
        if v > Decimal("999999999.99"):
            raise ValueError("Amount exceeds maximum")
        # Check for floating point issues
        if v != v.quantize(Decimal("0.01")):
            raise ValueError("Amount must have at most 2 decimal places")
        return v

@router.post("/orders")
async def create_order(items: list[OrderItem], current_user: dict = Depends(get_current_user)):
    # Calculate total with overflow protection
    total = Decimal("0")
    MAX_ORDER_TOTAL = Decimal("1000000.00")

    for item in items:
        item_total = item.unit_price * item.quantity
        total += item_total

        if total > MAX_ORDER_TOTAL:
            raise HTTPException(400, "Order total exceeds maximum")

    # Verify prices match current catalog (prevent price manipulation)
    for item in items:
        product = await db.products.find_one({"_id": ObjectId(item.product_id)})
        if Decimal(str(product["price"])) != item.unit_price:
            raise HTTPException(400, f"Price mismatch for product {item.product_id}")

    return await process_order(items, total)
```

---

## 50. Workflow Step Bypass Prevention

Multi-step processes (cart → shipping → payment → confirm) get attacked by jumping directly to final steps. Verify prerequisite state at each transition.

```python
from enum import Enum

class OrderState(str, Enum):
    CART = "cart"
    SHIPPING_SELECTED = "shipping_selected"
    PAYMENT_PENDING = "payment_pending"
    PAYMENT_COMPLETED = "payment_completed"
    CONFIRMED = "confirmed"

# Valid state transitions
STATE_TRANSITIONS = {
    OrderState.CART: [OrderState.SHIPPING_SELECTED],
    OrderState.SHIPPING_SELECTED: [OrderState.PAYMENT_PENDING, OrderState.CART],
    OrderState.PAYMENT_PENDING: [OrderState.PAYMENT_COMPLETED, OrderState.SHIPPING_SELECTED],
    OrderState.PAYMENT_COMPLETED: [OrderState.CONFIRMED],
    OrderState.CONFIRMED: [],  # Terminal state
}

async def transition_order_state(
    order_id: str,
    new_state: OrderState,
    user_id: str,
    db
) -> dict:
    """Atomically transition order state with validation."""

    # Find order and validate transition atomically
    order = await db.orders.find_one({
        "_id": ObjectId(order_id),
        "user_id": ObjectId(user_id)
    })

    if not order:
        raise HTTPException(404, "Order not found")

    current_state = OrderState(order["state"])

    # Check if transition is valid
    if new_state not in STATE_TRANSITIONS.get(current_state, []):
        raise HTTPException(
            400,
            f"Invalid state transition: {current_state} -> {new_state}"
        )

    # Validate prerequisites for each state
    if new_state == OrderState.PAYMENT_PENDING:
        if not order.get("shipping_address"):
            raise HTTPException(400, "Shipping address required")
        if not order.get("shipping_method"):
            raise HTTPException(400, "Shipping method required")

    if new_state == OrderState.PAYMENT_COMPLETED:
        if not order.get("payment_intent_id"):
            raise HTTPException(400, "Payment not initiated")

    if new_state == OrderState.CONFIRMED:
        if not order.get("payment_verified"):
            raise HTTPException(400, "Payment not verified")

    # Atomic update with state check
    result = await db.orders.update_one(
        {
            "_id": ObjectId(order_id),
            "state": current_state.value  # Ensure state hasn't changed
        },
        {
            "$set": {
                "state": new_state.value,
                "state_updated_at": datetime.utcnow()
            },
            "$push": {
                "state_history": {
                    "from": current_state.value,
                    "to": new_state.value,
                    "timestamp": datetime.utcnow()
                }
            }
        }
    )

    if result.modified_count == 0:
        raise HTTPException(409, "Order state changed. Please retry.")

    return {"state": new_state.value}

@router.post("/orders/{order_id}/confirm")
async def confirm_order(
    order_id: str,
    current_user: dict = Depends(get_current_user),
    db = Depends(get_database)
):
    # Cannot jump directly to confirmed - must go through state machine
    return await transition_order_state(
        order_id,
        OrderState.CONFIRMED,
        str(current_user["_id"]),
        db
    )
```

---

# Quick Reference

```python
# === AUTHENTICATION ===
# Validate tokens first, specify algorithm explicitly
payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])

# === AUTHORIZATION ===
# Always include ownership in queries
await db.docs.find_one({"_id": doc_id, "owner_id": user_id})

# === INPUT VALIDATION ===
# Use Pydantic with strict constraints
class Request(BaseModel):
    field: str = Field(..., min_length=1, max_length=100)

# === NOSQL INJECTION ===
# Block MongoDB operators in user input
if any(k.startswith("$") for k in user_dict.keys()):
    raise HTTPException(400, "Invalid input")

# === RATE LIMITING ===
@limiter.limit("5/minute")   # Auth routes
@limiter.limit("30/minute")  # Write routes
@limiter.limit("100/minute") # Read routes

# === ERROR HANDLING ===
logger.error(f"Error: {e}", exc_info=True)  # Internal
raise HTTPException(500, "An error occurred")  # External

# === RESPONSE FILTERING ===
return UserResponse(**user.dict())  # Never raw documents

# === ATOMIC OPERATIONS ===
# Check and update in single query
await db.users.update_one(
    {"_id": user_id, "credits": {"$gte": amount}},
    {"$inc": {"credits": -amount}}
)
```

---

# Security Checklist

Before deploying any route:

- [ ] **Authentication**: Token validated before any business logic?
- [ ] **Authorization**: Ownership verified at data layer?
- [ ] **Input Validation**: All inputs validated with Pydantic?
- [ ] **Injection**: MongoDB operators blocked in user input?
- [ ] **Rate Limiting**: Appropriate limits for operation type?
- [ ] **Error Handling**: Generic external errors, detailed internal logs?
- [ ] **Data Exposure**: Response model excludes sensitive fields?
- [ ] **SSRF**: URLs validated against internal ranges?
- [ ] **Business Logic**: Atomic operations, state machine transitions?
- [ ] **Logging**: Sensitive data redacted, audit trail maintained?
