---
name: MongoDB Schema Design Expert
description: Production-grade MongoDB schema design patterns for building highly scalable and performant database architectures, with deep expertise in embedding vs referencing, indexing strategies, sharding, and query optimization
---

# MongoDB Schema Design — 50 Best Practices for High Performance & Scalability

## Identity

You are a MongoDB schema architect who designs data models based on application access patterns, not theoretical normalization. You think in queries first, schema second—every collection is evaluated by how it will be read, written, and scaled. Your approach mirrors how distributed systems engineers think: you optimize for the common case, design for horizontal scalability, and build schemas that perform well under production load.

## Goal

Design MongoDB schemas that pass the "production scale test": queries complete in milliseconds with proper index coverage, documents never hit size limits, sharding distributes load evenly, and the schema evolves gracefully as requirements change without costly migrations.

---

# Core Intuitions: The "Why" Before the "How"

## Application-Driven Schema

The most important rule in MongoDB is that **access patterns dictate schema**. You do not design a schema in isolation; you design it to satisfy the specific queries your application will run most frequently.

**Intuition**: If you frequently read `User` and `Address` together, they should likely be in the same document. If you rarely read `OrderHistory` with `User`, they should be separate.

## Embed vs. Reference (The Golden Rule)

**Embed (Denormalize)**: Good for "contains" relationships (one-to-few). It reduces the need for expensive `$lookup` (joins) and ensures atomicity (you can update the whole document in one go).

**Reference (Normalize)**: Good for distinct entities (one-to-many/squillions). It prevents documents from hitting the 16MB size limit and avoids data duplication hell.

**Intuition**: Embed by default; reference when arrays grow without bound.

## Data Locality

MongoDB reads and writes data in pages. If related data is stored together (in the same document), a single disk read fetches everything you need.

**Intuition**: "Together on disk, together in memory."

## Write-Heavy vs. Read-Heavy

**Read-Heavy**: You can afford to duplicate data (denormalize) to make reads faster, even if it makes updates slower (because you have to update multiple places).

**Write-Heavy**: You want to normalize to ensure you only write to one place, keeping writes fast and lean.

---

# Schema Design & Modeling

## 1. Model for Queries, Not Data

Design your schema to match your most frequent queries. Start by listing all the queries your application will perform, then design documents that serve those queries efficiently.

```python
# BAD: Normalized like SQL - requires multiple queries
# users collection
{"_id": ObjectId("..."), "name": "John", "email": "john@example.com"}

# addresses collection (separate)
{"_id": ObjectId("..."), "user_id": ObjectId("..."), "street": "123 Main St", "city": "NYC"}

# GOOD: Embedded for common access pattern
# If you always fetch user with their addresses
{
    "_id": ObjectId("..."),
    "name": "John",
    "email": "john@example.com",
    "addresses": [
        {"street": "123 Main St", "city": "NYC", "type": "home"},
        {"street": "456 Work Ave", "city": "NYC", "type": "work"}
    ]
}
```

---

## 2. Embed for One-to-Few Relationships

Use embedding for relationships where the child side is small and bounded (e.g., addresses per user, phone numbers per contact).

```python
# User with embedded addresses (one-to-few)
user_document = {
    "_id": ObjectId(),
    "name": "Jane Doe",
    "email": "jane@example.com",
    "addresses": [
        {
            "type": "home",
            "street": "123 Elm Street",
            "city": "Springfield",
            "state": "IL",
            "zip": "62701"
        },
        {
            "type": "work",
            "street": "456 Corporate Blvd",
            "city": "Chicago",
            "state": "IL",
            "zip": "60601"
        }
    ],
    "phone_numbers": [
        {"type": "mobile", "number": "+1-555-0100"},
        {"type": "work", "number": "+1-555-0101"}
    ]
}

# Query is simple and atomic
user = await db.users.find_one({"_id": user_id})
# All data in one document - no joins needed
```

---

## 3. Reference for One-to-Many Relationships

Use references (ObjectIDs) when the "many" side is large but bounded (e.g., orders per customer, posts per user).

```python
# customers collection
customer = {
    "_id": ObjectId("customer_123"),
    "name": "Acme Corp",
    "email": "contact@acme.com"
}

# orders collection (separate, references customer)
order = {
    "_id": ObjectId(),
    "customer_id": ObjectId("customer_123"),  # Reference
    "order_date": datetime.utcnow(),
    "total": Decimal128("1250.00"),
    "items": [
        {"product_id": ObjectId("prod_1"), "quantity": 2, "price": Decimal128("500.00")},
        {"product_id": ObjectId("prod_2"), "quantity": 5, "price": Decimal128("50.00")}
    ],
    "status": "shipped"
}

# Query orders for a customer
orders = await db.orders.find({"customer_id": customer_id}).to_list(100)

# When you need customer details with orders, use $lookup sparingly
pipeline = [
    {"$match": {"customer_id": customer_id}},
    {"$lookup": {
        "from": "customers",
        "localField": "customer_id",
        "foreignField": "_id",
        "as": "customer"
    }},
    {"$unwind": "$customer"}
]
```

---

## 4. Reference for One-to-Squillions Relationships

For massive relationships (e.g., log entries, sensor readings), store the reference on the "many" side. Never store an array of millions of IDs on the "one" side.

```python
# BAD: Array of readings on sensor (will exceed 16MB)
sensor_bad = {
    "_id": ObjectId("sensor_001"),
    "name": "Temperature Sensor A",
    "readings": [
        {"timestamp": datetime(2024, 1, 1, 0, 0), "value": 23.5},
        {"timestamp": datetime(2024, 1, 1, 0, 1), "value": 23.6},
        # ... millions more readings
    ]
}

# GOOD: Reference stored on the "many" side
sensor_good = {
    "_id": ObjectId("sensor_001"),
    "name": "Temperature Sensor A",
    "location": "Building A, Floor 3",
    "type": "temperature"
}

reading = {
    "_id": ObjectId(),
    "sensor_id": ObjectId("sensor_001"),  # Reference to parent
    "timestamp": datetime.utcnow(),
    "value": 23.5
}

# Query readings for a sensor
readings = await db.readings.find({
    "sensor_id": sensor_id,
    "timestamp": {"$gte": start_date, "$lte": end_date}
}).sort("timestamp", -1).limit(1000).to_list(1000)
```

---

## 5. Avoid Unbounded Arrays

Never allow an array to grow indefinitely within a document. Unbounded arrays cause document growth, movement on disk, and eventually hit the 16MB limit.

```python
# BAD: Unbounded comments array
post_bad = {
    "_id": ObjectId(),
    "title": "Popular Post",
    "content": "...",
    "comments": [
        # This array can grow without limit!
        {"user": "user1", "text": "Great post!", "date": datetime.utcnow()},
        {"user": "user2", "text": "Thanks!", "date": datetime.utcnow()},
        # ... potentially thousands of comments
    ]
}

# GOOD: Separate collection with reference
post_good = {
    "_id": ObjectId("post_123"),
    "title": "Popular Post",
    "content": "...",
    "comment_count": 1547,  # Cached count for display
    "recent_comments": [  # Subset pattern - only keep latest 5
        {"user": "user1", "text": "Latest comment!", "date": datetime.utcnow()}
    ]
}

comment = {
    "_id": ObjectId(),
    "post_id": ObjectId("post_123"),
    "user_id": ObjectId("user_456"),
    "text": "Great post!",
    "created_at": datetime.utcnow()
}
```

---

## 6. Use the Bucket Pattern for Time-Series Data

Group readings into "buckets" within a single document to optimize storage, index size, and query performance.

```python
# BAD: One document per reading (billions of documents)
reading_bad = {
    "_id": ObjectId(),
    "sensor_id": ObjectId("sensor_001"),
    "timestamp": datetime(2024, 1, 1, 12, 0, 0),
    "value": 23.5
}

# GOOD: Bucket pattern - one document per hour/day
bucket_good = {
    "_id": ObjectId(),
    "sensor_id": ObjectId("sensor_001"),
    "bucket_start": datetime(2024, 1, 1, 12, 0, 0),  # Start of hour
    "bucket_end": datetime(2024, 1, 1, 12, 59, 59),
    "reading_count": 60,
    "readings": [
        {"minute": 0, "value": 23.5},
        {"minute": 1, "value": 23.6},
        {"minute": 2, "value": 23.4},
        # ... up to 60 readings per bucket
    ],
    "stats": {  # Pre-computed for fast queries
        "min": 23.1,
        "max": 24.2,
        "avg": 23.55,
        "sum": 1413.0
    }
}

# Index is much smaller (one per bucket, not one per reading)
# Queries for a time range hit fewer documents
async def get_hourly_stats(sensor_id: ObjectId, start: datetime, end: datetime):
    return await db.sensor_buckets.find({
        "sensor_id": sensor_id,
        "bucket_start": {"$gte": start},
        "bucket_end": {"$lte": end}
    }).to_list(None)
```

---

## 7. Schema Versioning

Include a `schema_version` field in documents to handle application-level migrations gracefully without downtime.

```python
from enum import IntEnum

class UserSchemaVersion(IntEnum):
    V1 = 1  # Original schema
    V2 = 2  # Added preferences
    V3 = 3  # Split name into first_name, last_name

CURRENT_SCHEMA_VERSION = UserSchemaVersion.V3

# Document with version tracking
user_v3 = {
    "_id": ObjectId(),
    "schema_version": CURRENT_SCHEMA_VERSION,
    "first_name": "John",
    "last_name": "Doe",
    "email": "john@example.com",
    "preferences": {"theme": "dark", "notifications": True}
}

# Migration function that runs on read
def migrate_user_document(doc: dict) -> dict:
    """Migrate old document versions to current schema."""
    version = doc.get("schema_version", 1)

    if version < 2:
        # V1 -> V2: Add default preferences
        doc["preferences"] = {"theme": "light", "notifications": True}
        doc["schema_version"] = 2
        version = 2

    if version < 3:
        # V2 -> V3: Split name field
        full_name = doc.pop("name", "Unknown User")
        parts = full_name.split(" ", 1)
        doc["first_name"] = parts[0]
        doc["last_name"] = parts[1] if len(parts) > 1 else ""
        doc["schema_version"] = 3

    return doc

# Usage in repository
async def get_user(user_id: ObjectId) -> dict:
    doc = await db.users.find_one({"_id": user_id})
    if not doc:
        return None

    if doc.get("schema_version", 1) < CURRENT_SCHEMA_VERSION:
        doc = migrate_user_document(doc)
        # Optionally persist the migration
        await db.users.replace_one({"_id": user_id}, doc)

    return doc
```

---

## 8. Embrace Polymorphism

It is acceptable to store documents with different fields in the same collection if they share a common access pattern. Use a discriminator field.

```python
# All notifications in one collection with different structures
notification_email = {
    "_id": ObjectId(),
    "type": "email",  # Discriminator
    "user_id": ObjectId("user_123"),
    "created_at": datetime.utcnow(),
    "status": "sent",
    # Email-specific fields
    "recipient": "user@example.com",
    "subject": "Welcome!",
    "body_html": "<h1>Welcome</h1>"
}

notification_sms = {
    "_id": ObjectId(),
    "type": "sms",  # Discriminator
    "user_id": ObjectId("user_123"),
    "created_at": datetime.utcnow(),
    "status": "pending",
    # SMS-specific fields
    "phone_number": "+1-555-0100",
    "message": "Your code is 123456"
}

notification_push = {
    "_id": ObjectId(),
    "type": "push",  # Discriminator
    "user_id": ObjectId("user_123"),
    "created_at": datetime.utcnow(),
    "status": "delivered",
    # Push-specific fields
    "device_token": "abc123...",
    "title": "New Message",
    "body": "You have a new message"
}

# Single index covers all notification types
# db.notifications.createIndex({"user_id": 1, "created_at": -1})

# Query all notifications for a user regardless of type
notifications = await db.notifications.find({
    "user_id": user_id
}).sort("created_at", -1).limit(50).to_list(50)

# Query specific type
email_notifications = await db.notifications.find({
    "user_id": user_id,
    "type": "email"
}).to_list(100)
```

---

## 9. Pre-allocate Space for Known Growth

If you know an array will grow to a certain size, pre-fill it with default values to avoid document movement during updates.

```python
# For a game leaderboard with fixed slots
def create_leaderboard(game_id: str, max_slots: int = 100):
    """Pre-allocate leaderboard slots to avoid document growth."""
    return {
        "_id": ObjectId(),
        "game_id": game_id,
        "updated_at": datetime.utcnow(),
        "slots": [
            {"rank": i + 1, "user_id": None, "score": 0, "username": ""}
            for i in range(max_slots)
        ]
    }

# Updates modify existing slots, don't grow the array
async def update_leaderboard_slot(game_id: str, rank: int, user_id: ObjectId, score: int, username: str):
    await db.leaderboards.update_one(
        {"game_id": game_id},
        {"$set": {
            f"slots.{rank - 1}": {
                "rank": rank,
                "user_id": user_id,
                "score": score,
                "username": username
            },
            "updated_at": datetime.utcnow()
        }}
    )

# For calendars - pre-allocate days in a month
def create_availability_calendar(user_id: ObjectId, year: int, month: int):
    import calendar
    days_in_month = calendar.monthrange(year, month)[1]

    return {
        "_id": ObjectId(),
        "user_id": user_id,
        "year": year,
        "month": month,
        "days": {
            str(day): {"available": True, "slots": []}
            for day in range(1, days_in_month + 1)
        }
    }
```

---

## 10. Keep Field Names Concise

While WiredTiger compression helps, shorter field names reduce network bandwidth and improve readability in large-scale systems.

```python
# Verbose (acceptable for clarity)
document_verbose = {
    "user_identifier": ObjectId(),
    "electronic_mail_address": "user@example.com",
    "date_of_registration": datetime.utcnow(),
    "subscription_tier_level": "premium"
}

# Concise (better for high-volume collections)
document_concise = {
    "uid": ObjectId(),
    "email": "user@example.com",
    "reg_date": datetime.utcnow(),
    "tier": "premium"
}

# For internal/technical fields, use abbreviations consistently
metrics_document = {
    "_id": ObjectId(),
    "ts": datetime.utcnow(),      # timestamp
    "sid": ObjectId(),             # sensor_id
    "val": 23.5,                   # value
    "cnt": 100,                    # count
    "avg": 23.45,                  # average
    "min": 22.1,                   # minimum
    "max": 24.8                    # maximum
}

# Document field name conventions
FIELD_ABBREVIATIONS = {
    "timestamp": "ts",
    "created_at": "cat",
    "updated_at": "uat",
    "deleted_at": "dat",
    "user_id": "uid",
    "organization_id": "oid",
    "count": "cnt",
    "value": "val"
}
```

---

## 11. Use Correct Data Types

Use MongoDB's specific types to ensure precision and enable proper queries.

```python
from bson import Decimal128, ObjectId
from datetime import datetime

# GOOD: Proper data types
product = {
    "_id": ObjectId(),
    "name": "Premium Widget",
    "price": Decimal128("99.99"),           # Decimal for currency (no floating point errors)
    "quantity": 150,                         # Integer for counts
    "weight_kg": 2.5,                        # Float for measurements
    "created_at": datetime.utcnow(),         # DateTime for timestamps
    "is_active": True,                       # Boolean
    "tags": ["electronics", "gadgets"],      # Array
    "metadata": {"sku": "WDG-001"},         # Embedded document
    "supplier_id": ObjectId("..."),          # ObjectId for references
}

# BAD: String types where specific types should be used
product_bad = {
    "_id": "some-uuid-string",              # Use ObjectId
    "price": "99.99",                        # Use Decimal128
    "quantity": "150",                       # Use Integer
    "created_at": "2024-01-15T10:30:00Z",   # Use DateTime
    "is_active": "true",                     # Use Boolean
}

# Date queries only work with proper DateTime types
# This query won't work if created_at is a string
await db.products.find({
    "created_at": {"$gte": datetime(2024, 1, 1), "$lt": datetime(2024, 2, 1)}
})

# Decimal128 for financial calculations
from decimal import Decimal

def calculate_order_total(items: list) -> Decimal128:
    total = Decimal("0")
    for item in items:
        price = item["price"].to_decimal()
        quantity = item["quantity"]
        total += price * quantity
    return Decimal128(total)
```

---

## 12. Use the Computed Pattern

Pre-calculate and store aggregations on the document rather than calculating them on every read.

```python
# Product with pre-computed statistics
product_with_stats = {
    "_id": ObjectId("product_123"),
    "name": "Wireless Headphones",
    "price": Decimal128("149.99"),
    # Pre-computed fields updated on write
    "stats": {
        "review_count": 1547,
        "average_rating": 4.3,
        "total_sales": 25000,
        "revenue": Decimal128("3749750.00")
    },
    "rating_distribution": {
        "5": 800,
        "4": 450,
        "3": 200,
        "2": 60,
        "1": 37
    }
}

# Update computed fields atomically when a review is added
async def add_review(product_id: ObjectId, rating: int):
    await db.products.update_one(
        {"_id": product_id},
        {
            "$inc": {
                "stats.review_count": 1,
                f"rating_distribution.{rating}": 1
            }
        }
    )

    # Recalculate average (or use running average formula)
    product = await db.products.find_one({"_id": product_id})
    dist = product["rating_distribution"]
    total_ratings = sum(int(k) * v for k, v in dist.items())
    total_reviews = sum(dist.values())
    new_avg = round(total_ratings / total_reviews, 1)

    await db.products.update_one(
        {"_id": product_id},
        {"$set": {"stats.average_rating": new_avg}}
    )

# Running average formula (more efficient)
async def add_review_running_avg(product_id: ObjectId, new_rating: int):
    """Update average using running average formula: new_avg = old_avg + (new_value - old_avg) / new_count"""
    await db.products.update_one(
        {"_id": product_id},
        [
            {"$set": {
                "stats.review_count": {"$add": ["$stats.review_count", 1]},
                f"rating_distribution.{new_rating}": {
                    "$add": [f"$rating_distribution.{new_rating}", 1]
                },
                "stats.average_rating": {
                    "$add": [
                        "$stats.average_rating",
                        {"$divide": [
                            {"$subtract": [new_rating, "$stats.average_rating"]},
                            {"$add": ["$stats.review_count", 1]}
                        ]}
                    ]
                }
            }}
        ]
    )
```

---

## 13. Use the Subset Pattern

If a document is large but you only need a small part frequently, embed that subset and reference the rest.

```python
# Movie with subset of reviews embedded
movie_document = {
    "_id": ObjectId("movie_123"),
    "title": "The Matrix",
    "year": 1999,
    "director": "Wachowskis",
    "plot": "A computer hacker learns about the true nature of reality...",
    "genres": ["Action", "Sci-Fi"],
    # Subset: Only the most recent/helpful reviews
    "featured_reviews": [
        {
            "user_id": ObjectId("user_1"),
            "username": "filmcritic",
            "rating": 5,
            "text": "A masterpiece of science fiction...",
            "helpful_votes": 1250,
            "date": datetime(2024, 1, 15)
        },
        {
            "user_id": ObjectId("user_2"),
            "username": "moviefan",
            "rating": 5,
            "text": "Changed cinema forever...",
            "helpful_votes": 890,
            "date": datetime(2024, 1, 10)
        }
        # Only keep top 5-10 reviews embedded
    ],
    "review_stats": {
        "count": 15420,
        "average": 4.7
    }
}

# Full reviews in separate collection
review_document = {
    "_id": ObjectId(),
    "movie_id": ObjectId("movie_123"),
    "user_id": ObjectId("user_3"),
    "username": "casualviewer",
    "rating": 4,
    "text": "Great movie, a bit long...",
    "helpful_votes": 45,
    "created_at": datetime.utcnow()
}

# Update featured reviews periodically or on new review
async def update_featured_reviews(movie_id: ObjectId):
    """Update the embedded subset with top reviews."""
    top_reviews = await db.reviews.find(
        {"movie_id": movie_id}
    ).sort("helpful_votes", -1).limit(5).to_list(5)

    featured = [
        {
            "user_id": r["user_id"],
            "username": r["username"],
            "rating": r["rating"],
            "text": r["text"][:200],  # Truncate for embedded version
            "helpful_votes": r["helpful_votes"],
            "date": r["created_at"]
        }
        for r in top_reviews
    ]

    await db.movies.update_one(
        {"_id": movie_id},
        {"$set": {"featured_reviews": featured}}
    )
```

---

## 14. Use the Extended Reference Pattern

When referencing, embed the most frequently needed fields to avoid a join just to display basic information.

```python
# BAD: Only store reference, requires $lookup for every display
order_bad = {
    "_id": ObjectId(),
    "customer_id": ObjectId("customer_123"),  # Only the ID
    "items": [...],
    "total": Decimal128("299.99")
}
# Need $lookup to get customer name for display

# GOOD: Extended reference with frequently needed fields
order_good = {
    "_id": ObjectId(),
    "customer": {
        "_id": ObjectId("customer_123"),  # Reference for joins when needed
        "name": "John Doe",                # Embedded for display
        "email": "john@example.com"        # Embedded for notifications
    },
    "items": [
        {
            "product": {
                "_id": ObjectId("prod_456"),
                "name": "Wireless Mouse",    # Embedded for display
                "sku": "WM-001"              # Embedded for receipts
            },
            "quantity": 2,
            "unit_price": Decimal128("49.99")
        }
    ],
    "shipping_address": {
        "name": "John Doe",
        "street": "123 Main St",
        "city": "New York",
        "state": "NY",
        "zip": "10001"
    },
    "total": Decimal128("99.98"),
    "created_at": datetime.utcnow()
}

# No $lookup needed for order listing or receipts
orders = await db.orders.find({"customer._id": customer_id}).to_list(100)

# Update denormalized fields when source changes
async def update_customer_name(customer_id: ObjectId, new_name: str):
    # Update source document
    await db.customers.update_one(
        {"_id": customer_id},
        {"$set": {"name": new_name}}
    )

    # Update denormalized copies (can be done async/eventually)
    await db.orders.update_many(
        {"customer._id": customer_id},
        {"$set": {"customer.name": new_name}}
    )
```

---

## 15. Model Hierarchical Data with Materialized Paths

Use Materialized Paths or Nested Sets for tree structures like categories, org charts, or comment threads.

```python
# Materialized Path Pattern for category hierarchy
# Electronics > Computers > Laptops > Gaming Laptops

category_document = {
    "_id": ObjectId("cat_gaming_laptops"),
    "name": "Gaming Laptops",
    "slug": "gaming-laptops",
    "path": "/electronics/computers/laptops/gaming-laptops",  # Full path
    "ancestors": [
        ObjectId("cat_electronics"),
        ObjectId("cat_computers"),
        ObjectId("cat_laptops")
    ],
    "parent_id": ObjectId("cat_laptops"),
    "depth": 3,
    "product_count": 150
}

# Find all descendants of "Computers"
descendants = await db.categories.find({
    "path": {"$regex": "^/electronics/computers/"}
}).to_list(None)

# Find all ancestors of a category
category = await db.categories.find_one({"_id": cat_id})
ancestors = await db.categories.find({
    "_id": {"$in": category["ancestors"]}
}).to_list(None)

# Array of Ancestors Pattern (alternative)
category_with_ancestors = {
    "_id": ObjectId(),
    "name": "Gaming Laptops",
    "ancestors": [
        {"_id": ObjectId("cat_electronics"), "name": "Electronics", "slug": "electronics"},
        {"_id": ObjectId("cat_computers"), "name": "Computers", "slug": "computers"},
        {"_id": ObjectId("cat_laptops"), "name": "Laptops", "slug": "laptops"}
    ],
    "parent": {"_id": ObjectId("cat_laptops"), "name": "Laptops"}
}

# Breadcrumb is immediately available without queries
breadcrumb = [a["name"] for a in category_with_ancestors["ancestors"]]
# ['Electronics', 'Computers', 'Laptops']
```

---

## 16. Use the Outlier Pattern for Variable-Size Documents

Handle documents that occasionally exceed normal patterns by flagging and extending them separately.

```python
# Normal book with few reviews
book_normal = {
    "_id": ObjectId("book_123"),
    "title": "Technical Manual",
    "reviews": [
        {"user": "reader1", "rating": 4, "text": "Helpful"},
        {"user": "reader2", "rating": 5, "text": "Great reference"}
    ],
    "has_overflow": False
}

# Bestseller with overflow flag
book_popular = {
    "_id": ObjectId("book_456"),
    "title": "Bestseller Novel",
    "reviews": [
        # First 100 reviews embedded
    ],
    "has_overflow": True,
    "overflow_count": 45000
}

# Overflow documents for outliers
review_overflow = {
    "_id": ObjectId(),
    "book_id": ObjectId("book_456"),
    "reviews": [
        # Next batch of reviews
    ],
    "batch_number": 1
}

# Query logic handles both cases
async def get_book_reviews(book_id: ObjectId, page: int = 1, per_page: int = 20):
    book = await db.books.find_one({"_id": book_id})

    if not book["has_overflow"] or page == 1:
        # Return from embedded reviews
        start = (page - 1) * per_page
        return book["reviews"][start:start + per_page]
    else:
        # Fetch from overflow collection
        skip = (page - 1) * per_page - len(book["reviews"])
        return await db.review_overflow.find(
            {"book_id": book_id}
        ).skip(skip).limit(per_page).to_list(per_page)
```

---

# Indexing Strategy

## 17. Follow the ESR Rule

Build compound indexes in the order of **E**quality, **S**ort, **R**ange. This maximizes index efficiency.

```python
# Query: Find active users in a city, sorted by created_at, in a date range
# db.users.find({status: "active", city: "NYC", created_at: {$gte: start, $lte: end}}).sort({created_at: -1})

# GOOD: ESR order
# E: status (equality) + city (equality)
# S: created_at (sort)
# R: created_at (range) - same field as sort, so it's covered
db.users.create_index([
    ("status", 1),       # E - Equality first
    ("city", 1),         # E - Equality second
    ("created_at", -1)   # S+R - Sort and Range last
])

# BAD: Range before Equality
db.users.create_index([
    ("created_at", -1),  # R - Range first (wrong!)
    ("status", 1),       # E
    ("city", 1)          # E
])

# ESR Examples:
# Query: {status: "published", category: "tech"} sort: {views: -1}
# Index: {status: 1, category: 1, views: -1}

# Query: {user_id: ObjectId, type: "comment"} sort: {created_at: -1}
# Index: {user_id: 1, type: 1, created_at: -1}

# Query: {tenant_id: ObjectId, created_at: {$gte: date}} sort: {created_at: 1}
# Index: {tenant_id: 1, created_at: 1}
```

---

## 18. Design for Covered Queries

Create indexes that contain all fields a query needs so MongoDB can satisfy the query entirely from RAM without touching disk.

```python
# Query that only needs specific fields
# db.users.find({status: "active"}, {email: 1, name: 1, _id: 0})

# Covered index: includes all query and projection fields
db.users.create_index([
    ("status", 1),
    ("email", 1),
    ("name", 1)
])

# This query is fully covered - no document fetch needed
result = await db.users.find(
    {"status": "active"},
    {"email": 1, "name": 1, "_id": 0}  # Must exclude _id if not in index
).to_list(100)

# Check if query is covered using explain()
explain_result = await db.users.find(
    {"status": "active"},
    {"email": 1, "name": 1, "_id": 0}
).explain()

# Look for: "totalDocsExamined": 0 (covered query indicator)

# Common covered query patterns:
# 1. Listing emails for notification
db.users.create_index([("status", 1), ("email", 1)])

# 2. Counting by category
db.products.create_index([("category", 1), ("status", 1)])

# 3. Lookup tables
db.config.create_index([("key", 1), ("value", 1)])
```

---

## 19. Avoid Index Bloat

Each index makes writes slower and consumes RAM. Find the balance and audit regularly.

```python
# Check index usage statistics
async def audit_index_usage(collection_name: str):
    """Identify unused or underused indexes."""
    stats = await db.command("aggregate", collection_name, pipeline=[
        {"$indexStats": {}}
    ], cursor={})

    unused_indexes = []
    for idx in stats["cursor"]["firstBatch"]:
        if idx["accesses"]["ops"] == 0:
            unused_indexes.append({
                "name": idx["name"],
                "key": idx["key"],
                "since": idx["accesses"]["since"]
            })

    return unused_indexes

# Check index sizes
async def get_index_sizes(collection_name: str):
    stats = await db.command("collStats", collection_name)
    return {
        "total_index_size": stats["totalIndexSize"],
        "index_sizes": stats["indexSizes"]
    }

# Guidelines for index count:
# - 5-10 indexes per collection is typical
# - More than 15 indexes warrants review
# - Each index adds ~10% write overhead

# Remove unused indexes
await db.users.drop_index("old_unused_index_1")

# Consolidate overlapping indexes
# If you have: {a: 1} and {a: 1, b: 1}
# The second index covers queries on {a: 1}, so drop the first
```

---

## 20. Use TTL Indexes for Auto-Expiration

Automatically delete old data using Time-To-Live indexes for sessions, logs, and temporary data.

```python
# Session documents with TTL
session_document = {
    "_id": ObjectId(),
    "user_id": ObjectId("user_123"),
    "token": "abc123...",
    "created_at": datetime.utcnow(),
    "expires_at": datetime.utcnow() + timedelta(hours=24)  # TTL field
}

# TTL index - MongoDB deletes documents after expires_at passes
db.sessions.create_index(
    "expires_at",
    expireAfterSeconds=0  # Delete when expires_at is reached
)

# Alternative: Delete X seconds after a timestamp
db.logs.create_index(
    "created_at",
    expireAfterSeconds=86400 * 30  # Delete 30 days after created_at
)

# Verification code with short TTL
verification = {
    "_id": ObjectId(),
    "user_id": ObjectId(),
    "code": "123456",
    "created_at": datetime.utcnow()
}

db.verifications.create_index(
    "created_at",
    expireAfterSeconds=600  # Delete after 10 minutes
)

# Rate limit entries
rate_limit_entry = {
    "_id": f"{user_id}:{endpoint}:{minute_bucket}",
    "count": 1,
    "expires_at": datetime.utcnow() + timedelta(minutes=1)
}

db.rate_limits.create_index("expires_at", expireAfterSeconds=0)
```

---

## 21. Use Partial Indexes

Only index documents that meet specific criteria to save RAM and improve write performance.

```python
# Only index active users (most common query)
db.users.create_index(
    [("email", 1)],
    partialFilterExpression={"status": "active"}
)

# Only index unprocessed jobs
db.jobs.create_index(
    [("priority", -1), ("created_at", 1)],
    partialFilterExpression={"status": {"$in": ["pending", "queued"]}}
)

# Only index premium customers
db.customers.create_index(
    [("subscription_end", 1)],
    partialFilterExpression={"tier": {"$in": ["premium", "enterprise"]}}
)

# Sparse equivalent with partial
db.users.create_index(
    [("phone", 1)],
    partialFilterExpression={"phone": {"$exists": True}},
    unique=True
)

# Query must match partial filter to use index
# This uses the index:
await db.users.find({"email": "test@example.com", "status": "active"})

# This does NOT use the index (missing status filter):
await db.users.find({"email": "test@example.com"})

# Size comparison
# Full index on 10M users: ~400MB
# Partial index (20% active): ~80MB
```

---

## 22. Use Sparse Indexes

Only index documents that actually have the indexed field, useful for optional fields with unique constraints.

```python
# Optional unique field (not all users have phone)
db.users.create_index(
    [("phone", 1)],
    sparse=True,
    unique=True
)

# This allows multiple documents without phone field
user_with_phone = {"name": "John", "phone": "+1-555-0100"}
user_without_phone = {"name": "Jane"}  # No phone field - not in index

# External ID that only some records have
db.products.create_index(
    [("external_sku", 1)],
    sparse=True,
    unique=True
)

# Note: Sparse indexes won't be used for queries that sort by the field
# if null/missing values need to be included in results

# Prefer partial indexes in modern MongoDB (more flexible)
db.users.create_index(
    [("phone", 1)],
    partialFilterExpression={"phone": {"$type": "string"}},
    unique=True
)
```

---

## 23. Build Indexes in Background

Always build indexes without blocking operations in production. Modern MongoDB versions handle this better, but be aware of the impact.

```python
# Background index creation (explicit)
db.large_collection.create_index(
    [("field", 1)],
    background=True  # Deprecated in 4.2+ but still accepted
)

# In MongoDB 4.2+, index builds are optimized automatically
# But you can still control it
db.admin.command({
    "createIndexes": "collection_name",
    "indexes": [{"key": {"field": 1}, "name": "field_1"}],
    "commitQuorum": "votingMembers"  # Wait for replicas
})

# For very large collections, monitor progress
async def monitor_index_build():
    while True:
        ops = await db.admin.command("currentOp", {"$all": True})
        index_builds = [
            op for op in ops.get("inprog", [])
            if op.get("msg", "").startswith("Index Build")
        ]

        for build in index_builds:
            print(f"Index build progress: {build.get('progress', {})}")

        if not index_builds:
            break

        await asyncio.sleep(10)

# Schedule index builds during low-traffic periods
# Use rolling index builds in replica sets
```

---

## 24. Use Index Prefix Compression

Place low-cardinality fields at the start of compound indexes to aid compression.

```python
# Low cardinality fields first for better compression
# status: ~5 unique values
# tenant_id: ~1000 unique values
# user_id: ~1M unique values
# created_at: ~infinite unique values

# GOOD: Low cardinality prefix
db.orders.create_index([
    ("status", 1),        # ~5 values - highly compressible prefix
    ("tenant_id", 1),     # ~1000 values
    ("created_at", -1)    # High cardinality
])

# Query patterns this supports:
# 1. {status: "pending"}
# 2. {status: "pending", tenant_id: X}
# 3. {status: "pending", tenant_id: X, created_at: {$gte: date}}

# Index key compression works best with repeated prefixes
# Index entries:
# ("pending", tenant_1, 2024-01-15)
# ("pending", tenant_1, 2024-01-14)  # "pending" and "tenant_1" compressed
# ("pending", tenant_1, 2024-01-13)
# ("pending", tenant_2, 2024-01-15)  # "pending" compressed

# This also improves cache efficiency
```

---

## 25. Use Wildcard Indexes for Dynamic Schemas

Use `$**` wildcard indexes when you have user-defined fields or attributes that all need to be searchable.

```python
# Product with dynamic attributes
product_dynamic = {
    "_id": ObjectId(),
    "name": "Laptop",
    "category": "electronics",
    "attributes": {
        "brand": "Dell",
        "ram_gb": 16,
        "storage_type": "SSD",
        "screen_size": 15.6,
        "color": "silver",
        # Users can add any attributes
        "custom_field_1": "value1",
        "custom_field_2": 123
    }
}

# Wildcard index on attributes subdocument
db.products.create_index({"attributes.$**": 1})

# Now any attribute is searchable
await db.products.find({"attributes.brand": "Dell"})
await db.products.find({"attributes.ram_gb": {"$gte": 16}})
await db.products.find({"attributes.custom_field_1": "value1"})

# Wildcard index with projection (limit which fields are indexed)
db.products.create_index(
    {"$**": 1},
    wildcardProjection={
        "attributes": 1,
        "metadata": 1
        # Only index these subdocuments
    }
)

# Exclude specific fields from wildcard
db.products.create_index(
    {"$**": 1},
    wildcardProjection={
        "large_text_field": 0,
        "binary_data": 0
    }
)
```

---

# Performance Tuning & Queries

## 26. Always Use Projections

Return only the fields you need to save network bandwidth and memory.

```python
# BAD: Fetch entire document when you only need a few fields
user = await db.users.find_one({"_id": user_id})
print(f"Hello, {user['name']}")

# GOOD: Project only needed fields
user = await db.users.find_one(
    {"_id": user_id},
    {"name": 1, "email": 1}  # Only fetch name and email
)

# Exclude large fields
user = await db.users.find_one(
    {"_id": user_id},
    {"profile_image": 0, "activity_log": 0}  # Exclude large fields
)

# For listings, be aggressive with projections
users = await db.users.find(
    {"status": "active"},
    {"name": 1, "avatar_url": 1, "created_at": 1}
).limit(50).to_list(50)

# Projection reduces:
# - Network transfer (especially important for large documents)
# - Memory usage on client
# - Deserialization time

# Benchmark difference on 100KB average document:
# Without projection: 100KB * 1000 docs = 100MB transferred
# With projection (1KB): 1KB * 1000 docs = 1MB transferred
```

---

## 27. Avoid $ne (Not Equal) Queries

Negation queries are hard to index effectively. Rephrase as positive assertions when possible.

```python
# BAD: $ne is inefficient (scans most of the index)
inactive_users = await db.users.find({"status": {"$ne": "active"}}).to_list(None)

# GOOD: Use $in with explicit values
inactive_users = await db.users.find({
    "status": {"$in": ["inactive", "suspended", "deleted"]}
}).to_list(None)

# BAD: $nin is also inefficient
non_premium = await db.users.find({
    "tier": {"$nin": ["premium", "enterprise"]}
}).to_list(None)

# GOOD: Explicit positive match
basic_users = await db.users.find({
    "tier": {"$in": ["free", "basic"]}
}).to_list(None)

# If you must use negation, combine with an indexed equality
# This at least uses the index for the first filter
non_premium_active = await db.users.find({
    "status": "active",  # Uses index
    "tier": {"$ne": "premium"}  # Filtered after
}).to_list(None)

# Query analysis
explain = await db.users.find({"status": {"$ne": "active"}}).explain()
# Will show high "totalDocsExamined" relative to "nReturned"
```

---

## 28. Avoid Unanchored Regular Expressions

Regex patterns starting with wildcards scan the entire index. Use text indexes or anchored patterns.

```python
# BAD: Unanchored regex (full index scan)
results = await db.products.find({
    "name": {"$regex": ".*phone.*", "$options": "i"}
}).to_list(100)

# BAD: Leading wildcard
results = await db.products.find({
    "name": {"$regex": "^.*phone"}
}).to_list(100)

# GOOD: Anchored prefix (uses index)
results = await db.products.find({
    "name": {"$regex": "^iPhone", "$options": "i"}
}).to_list(100)

# GOOD: Text index for full-text search
db.products.create_index({"name": "text", "description": "text"})

results = await db.products.find({
    "$text": {"$search": "phone wireless"}
}).to_list(100)

# GOOD: Pre-computed searchable fields
product = {
    "_id": ObjectId(),
    "name": "iPhone 15 Pro",
    "name_lowercase": "iphone 15 pro",  # For case-insensitive prefix search
    "name_tokens": ["iphone", "15", "pro"]  # For token matching
}

# Case-insensitive prefix search
results = await db.products.find({
    "name_lowercase": {"$regex": "^iphone"}
}).to_list(100)

# Token search
results = await db.products.find({
    "name_tokens": "iphone"
}).to_list(100)
```

---

## 29. Use explain() Habitually

Always check query plans to ensure you're hitting indexes (IXSCAN) and not doing full collection scans (COLLSCAN).

```python
# Get query execution stats
async def analyze_query(collection, query, projection=None):
    cursor = collection.find(query, projection)
    explain = await cursor.explain("executionStats")

    stats = explain["executionStats"]
    plan = explain["queryPlanner"]["winningPlan"]

    analysis = {
        "execution_time_ms": stats["executionTimeMillis"],
        "documents_examined": stats["totalDocsExamined"],
        "documents_returned": stats["nReturned"],
        "index_keys_examined": stats["totalKeysExamined"],
        "stage": plan.get("stage") or plan.get("inputStage", {}).get("stage"),
        "index_used": None
    }

    # Check for index usage
    def find_index(stage):
        if stage.get("stage") == "IXSCAN":
            return stage.get("indexName")
        if "inputStage" in stage:
            return find_index(stage["inputStage"])
        return None

    analysis["index_used"] = find_index(plan)

    # Warnings
    analysis["warnings"] = []
    if analysis["stage"] == "COLLSCAN":
        analysis["warnings"].append("FULL COLLECTION SCAN - add an index!")
    if analysis["documents_examined"] > analysis["documents_returned"] * 10:
        analysis["warnings"].append("Examining many more docs than returning - index may be suboptimal")

    return analysis

# Usage
result = await analyze_query(
    db.users,
    {"status": "active", "created_at": {"$gte": datetime(2024, 1, 1)}}
)
print(result)
# {
#   "execution_time_ms": 5,
#   "documents_examined": 1000,
#   "documents_returned": 1000,
#   "index_keys_examined": 1000,
#   "stage": "IXSCAN",
#   "index_used": "status_1_created_at_-1",
#   "warnings": []
# }
```

---

## 30. Limit Sort Operations

Sorting without an index is expensive and will fail if it exceeds the 32MB memory limit.

```python
# BAD: Sort on non-indexed field (in-memory sort, 32MB limit)
try:
    results = await db.logs.find({}).sort("timestamp", -1).to_list(None)
except Exception as e:
    # "Sort exceeded memory limit of 104857600 bytes"
    pass

# GOOD: Create index that supports the sort
db.logs.create_index([("timestamp", -1)])

# GOOD: Use allowDiskUse for large sorts (still slow, but won't fail)
results = await db.logs.aggregate([
    {"$sort": {"timestamp": -1}},
    {"$limit": 1000}
], allowDiskUse=True).to_list(1000)

# GOOD: Compound index supports both filter and sort
db.orders.create_index([("user_id", 1), ("created_at", -1)])

# This uses the index for both filter AND sort
results = await db.orders.find(
    {"user_id": user_id}
).sort("created_at", -1).limit(50).to_list(50)

# Check if sort is using index
explain = await db.orders.find(
    {"user_id": user_id}
).sort("created_at", -1).explain()

# Look for: "stage": "SORT" = BAD (in-memory)
# Look for: no SORT stage and IXSCAN with the right direction = GOOD
```

---

## 31. Use Bulk Operations

Use `bulk_write` for batch inserts/updates to reduce network round-trips.

```python
from pymongo import InsertOne, UpdateOne, DeleteOne, ReplaceOne

# BAD: Individual operations (N network round-trips)
for user in users_to_update:
    await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"status": "processed"}}
    )

# GOOD: Bulk operation (1 network round-trip)
operations = [
    UpdateOne(
        {"_id": user["_id"]},
        {"$set": {"status": "processed"}}
    )
    for user in users_to_update
]

result = await db.users.bulk_write(operations, ordered=False)
print(f"Modified: {result.modified_count}")

# Mixed bulk operations
operations = [
    InsertOne({"name": "New User", "email": "new@example.com"}),
    UpdateOne({"_id": existing_id}, {"$inc": {"login_count": 1}}),
    DeleteOne({"_id": old_id}),
    ReplaceOne({"_id": replace_id}, new_document)
]

result = await db.users.bulk_write(operations, ordered=False)

# Ordered vs Unordered:
# ordered=True: Stops on first error (default)
# ordered=False: Continues on errors, better performance

# Batch size recommendations:
# - 1000-5000 operations per bulk_write
# - Keep total size under 16MB
# - Use ordered=False for independent operations
```

---

## 32. Tune Write Concern for Your Needs

Adjust `w` (write concern) based on the importance of the data.

```python
from pymongo import WriteConcern

# Fastest writes (fire and forget) - USE WITH CAUTION
# Data may be lost if server crashes
fast_collection = db.logs.with_options(
    write_concern=WriteConcern(w=0)
)
await fast_collection.insert_one({"event": "page_view"})

# Default: Acknowledged by primary
# Good balance of speed and safety
default_collection = db.orders.with_options(
    write_concern=WriteConcern(w=1)
)

# Durable: Acknowledged by majority of replica set
# Use for critical data
durable_collection = db.payments.with_options(
    write_concern=WriteConcern(w="majority")
)
await durable_collection.insert_one({"amount": 100, "status": "completed"})

# Maximum durability: Majority + journal
critical_collection = db.financial_transactions.with_options(
    write_concern=WriteConcern(w="majority", j=True)
)

# Per-operation write concern
await db.users.insert_one(
    {"name": "Critical User"},
    write_concern=WriteConcern(w="majority", j=True)
)

# Write concern by use case:
# w=0: Logs, metrics, analytics (loss acceptable)
# w=1: User preferences, session data (default)
# w="majority": Orders, user accounts (important)
# w="majority", j=True: Payments, audit logs (critical)
```

---

## 33. Use Read Preference for Load Distribution

Offload read queries to secondary nodes for analytics and reporting.

```python
from pymongo import ReadPreference

# Primary only (default) - for real-time data
primary_collection = db.users.with_options(
    read_preference=ReadPreference.PRIMARY
)

# Primary preferred - use primary if available
primary_preferred = db.users.with_options(
    read_preference=ReadPreference.PRIMARY_PREFERRED
)

# Secondary preferred - good for analytics (may be slightly stale)
analytics_collection = db.orders.with_options(
    read_preference=ReadPreference.SECONDARY_PREFERRED
)

# Generate report from secondary
async def generate_daily_report():
    return await analytics_collection.aggregate([
        {"$match": {"created_at": {"$gte": yesterday}}},
        {"$group": {"_id": "$status", "count": {"$sum": 1}}}
    ]).to_list(None)

# Nearest - lowest latency (good for geographically distributed reads)
nearest_collection = db.content.with_options(
    read_preference=ReadPreference.NEAREST
)

# Read preference with tags (for geo-aware routing)
from pymongo.read_preferences import Secondary

geo_collection = db.users.with_options(
    read_preference=Secondary(tag_sets=[{"region": "us-east"}])
)

# Use cases:
# PRIMARY: Shopping cart, checkout, real-time updates
# PRIMARY_PREFERRED: User profiles, most reads
# SECONDARY_PREFERRED: Reports, analytics, search
# SECONDARY: Backups, batch processing
# NEAREST: CDN-like content, latency-sensitive reads
```

---

## 34. Minimize $lookup Operations

Joins are expensive in distributed systems. Design schemas to avoid them where possible.

```python
# BAD: $lookup for every request
pipeline_bad = [
    {"$match": {"user_id": user_id}},
    {"$lookup": {
        "from": "users",
        "localField": "user_id",
        "foreignField": "_id",
        "as": "user"
    }},
    {"$unwind": "$user"}
]

# GOOD: Extended reference pattern (embed needed fields)
order_with_user = {
    "_id": ObjectId(),
    "user": {
        "_id": ObjectId("user_123"),
        "name": "John Doe",  # Embedded for display
        "email": "john@example.com"
    },
    "items": [...],
    "total": Decimal128("99.99")
}

# No $lookup needed for common operations

# If you must use $lookup, optimize it:
# 1. Filter before $lookup (reduce documents to join)
pipeline_optimized = [
    {"$match": {"status": "pending", "created_at": {"$gte": yesterday}}},  # Filter first
    {"$lookup": {
        "from": "users",
        "localField": "user_id",
        "foreignField": "_id",
        "as": "user",
        "pipeline": [  # Sub-pipeline to limit fields
            {"$project": {"name": 1, "email": 1}}
        ]
    }},
    {"$unwind": "$user"}
]

# 2. Ensure foreign field is indexed
db.users.create_index([("_id", 1)])  # Usually exists by default

# 3. Use $graphLookup sparingly (recursive, very expensive)
```

---

## 35. Use Hints When Optimizer Chooses Wrong

In rare cases where the query optimizer chooses a suboptimal index, use `.hint()` to force the correct one.

```python
# Normally, let MongoDB choose the index
results = await db.orders.find({
    "status": "pending",
    "created_at": {"$gte": yesterday}
}).to_list(100)

# Check which index was used
explain = await db.orders.find({
    "status": "pending",
    "created_at": {"$gte": yesterday}
}).explain()

# If optimizer chose wrong index, force the correct one
results = await db.orders.find({
    "status": "pending",
    "created_at": {"$gte": yesterday}
}).hint("status_1_created_at_-1").to_list(100)

# Hint with index specification
results = await db.orders.find({
    "status": "pending"
}).hint([("status", 1), ("priority", -1)]).to_list(100)

# Force collection scan (rare, for comparison)
results = await db.orders.find({
    "status": "pending"
}).hint({"$natural": 1}).to_list(100)

# When to use hints:
# - Query planner consistently chooses wrong index
# - After confirming with explain() that another index is better
# - Testing/benchmarking different indexes

# Warning: Hints are fragile
# - Index must exist (error if dropped)
# - May become suboptimal as data changes
# - Prefer fixing schema/indexes over hints
```

---

# Scalability & Sharding

## 36. Plan for Sharding Early

Don't wait until your system is overwhelmed to implement sharding. Design shard-key-friendly schemas from the start.

```python
# Design documents with sharding in mind from day one
order_document = {
    "_id": ObjectId(),
    "tenant_id": ObjectId("tenant_123"),  # Good shard key candidate
    "user_id": ObjectId("user_456"),
    "created_at": datetime.utcnow(),
    "items": [...],
    "total": Decimal128("99.99")
}

# Include shard key in all queries (otherwise scatter-gather)
# GOOD: Query includes shard key
orders = await db.orders.find({
    "tenant_id": tenant_id,  # Shard key
    "status": "pending"
}).to_list(100)

# BAD: Query without shard key (hits all shards)
orders = await db.orders.find({
    "status": "pending"
}).to_list(100)

# Pre-sharding setup (before going live)
# 1. Enable sharding on database
# db.admin.command("enableSharding", "mydb")

# 2. Create index on shard key (required)
# db.orders.create_index([("tenant_id", 1), ("_id", 1)])

# 3. Shard the collection
# db.admin.command("shardCollection", "mydb.orders", key={"tenant_id": 1, "_id": 1})
```

---

## 37. Choose a Good Shard Key

The shard key choice is critical and often irreversible. Prioritize high cardinality and even distribution.

```python
# GOOD Shard Keys:
# 1. Compound: tenant_id + _id (distributes within tenant)
shard_key_compound = {"tenant_id": 1, "_id": 1}

# 2. Hashed _id (even distribution, but loses ordering)
shard_key_hashed = {"_id": "hashed"}

# 3. Compound with hashed (balance of both)
# Not directly supported, simulate with computed field

# BAD Shard Keys:
# 1. Monotonically increasing (timestamp, ObjectId alone)
shard_key_bad_1 = {"created_at": 1}  # All writes go to one shard

# 2. Low cardinality
shard_key_bad_2 = {"status": 1}  # Only a few values, can't distribute

# 3. Random but not query-friendly
shard_key_bad_3 = {"random_uuid": 1}  # Good distribution, bad for queries

# Shard Key Evaluation Criteria:
# 1. Cardinality: High (millions of unique values)
# 2. Frequency: Even (no hot values)
# 3. Query isolation: Most queries include the key
# 4. Write distribution: Writes spread across shards

# Testing shard key distribution
async def analyze_shard_key_distribution(collection, shard_key_field):
    """Analyze how well a field would work as shard key."""
    pipeline = [
        {"$group": {
            "_id": f"${shard_key_field}",
            "count": {"$sum": 1}
        }},
        {"$group": {
            "_id": None,
            "total_unique": {"$sum": 1},
            "max_count": {"$max": "$count"},
            "min_count": {"$min": "$count"},
            "avg_count": {"$avg": "$count"},
            "std_dev": {"$stdDevPop": "$count"}
        }}
    ]

    result = await collection.aggregate(pipeline).to_list(1)
    return result[0] if result else None
```

---

## 38. Avoid Monotonically Increasing Shard Keys

Keys that strictly increase (timestamps, auto-increment IDs) cause all writes to hit a single shard (hotspot).

```python
# BAD: Timestamp shard key (all recent writes to one shard)
log_bad = {
    "_id": ObjectId(),  # ObjectId starts with timestamp!
    "created_at": datetime.utcnow(),  # Monotonic
    "message": "Event occurred"
}
# Shard key: {"created_at": 1} - HOTSPOT!

# GOOD: Add high-cardinality prefix
log_good = {
    "_id": ObjectId(),
    "source_id": ObjectId("source_123"),  # High cardinality
    "created_at": datetime.utcnow(),
    "message": "Event occurred"
}
# Shard key: {"source_id": 1, "created_at": 1} - Distributed!

# GOOD: Use hashed shard key
# db.admin.command("shardCollection", "mydb.logs", key={"_id": "hashed"})

# GOOD: Compound key with write distribution
sensor_reading = {
    "_id": ObjectId(),
    "sensor_id": ObjectId("sensor_456"),  # Distributes writes
    "timestamp": datetime.utcnow(),
    "value": 23.5
}
# Shard key: {"sensor_id": 1, "timestamp": 1}
# Writes distributed across sensors
```

---

## 39. Use Hashed Sharding for Even Distribution

If you must use a monotonic key, use a hashed index to scatter writes evenly.

```python
# Hashed sharding on _id (ObjectId is monotonic, but hash distributes it)
# db.admin.command("shardCollection", "mydb.events", key={"_id": "hashed"})

# Document with hashed _id sharding
event = {
    "_id": ObjectId(),  # Hash of this is used for shard routing
    "type": "page_view",
    "user_id": ObjectId("user_123"),
    "timestamp": datetime.utcnow()
}

# Trade-offs of hashed sharding:
# PROS:
# - Even write distribution
# - No hotspots
# - Simple to implement

# CONS:
# - Lose range queries on shard key
# - Scatter-gather for range scans
# - Can't do targeted queries like "all events in time range"

# Hybrid approach: Computed hash field
import hashlib

def compute_shard_key(user_id: str, timestamp: datetime) -> str:
    """Compute a shard key that balances distribution and locality."""
    # Use hour bucket to maintain some locality
    hour_bucket = timestamp.strftime("%Y%m%d%H")
    # Hash user_id for distribution
    user_hash = hashlib.md5(user_id.encode()).hexdigest()[:8]
    return f"{user_hash}:{hour_bucket}"

event_hybrid = {
    "_id": ObjectId(),
    "shard_key": compute_shard_key(str(user_id), datetime.utcnow()),
    "user_id": user_id,
    "timestamp": datetime.utcnow(),
    "type": "page_view"
}
```

---

## 40. Use Zone Sharding for Data Locality

Keep data geographically close to users or tier storage between hot and cold data.

```python
# Geographic zone sharding
# Users in EU stored on EU shards, US users on US shards

user_with_region = {
    "_id": ObjectId(),
    "region": "eu",  # Used for zone routing
    "email": "user@example.eu",
    "name": "European User"
}

# Zone configuration (run on mongos)
"""
# Add shards to zones
sh.addShardTag("shard-eu-1", "EU")
sh.addShardTag("shard-eu-2", "EU")
sh.addShardTag("shard-us-1", "US")
sh.addShardTag("shard-us-2", "US")

# Define zone ranges
sh.addTagRange("mydb.users", {"region": "eu"}, {"region": "eu\xff"}, "EU")
sh.addTagRange("mydb.users", {"region": "us"}, {"region": "us\xff"}, "US")
"""

# Hot/Cold tiering
# Recent data on fast SSDs, old data on cheaper storage

order_with_date = {
    "_id": ObjectId(),
    "created_at": datetime.utcnow(),
    "status": "completed",
    "items": [...]
}

# Zone configuration for tiering
"""
# Hot zone (SSD shards) for recent data
sh.addTagRange("mydb.orders",
    {"created_at": ISODate("2024-01-01")},
    {"created_at": MaxKey},
    "HOT")

# Cold zone (HDD shards) for old data
sh.addTagRange("mydb.orders",
    {"created_at": MinKey},
    {"created_at": ISODate("2024-01-01")},
    "COLD")
"""

# Move data between tiers periodically
async def archive_old_data(cutoff_date: datetime):
    """Move old data to archive by updating zone-routing field."""
    await db.orders.update_many(
        {"created_at": {"$lt": cutoff_date}, "tier": "hot"},
        {"$set": {"tier": "cold"}}
    )
```

---

## 41. Pre-split Chunks for Bulk Loading

When bulk loading data, pre-split chunks to avoid the balancer working overtime.

```python
# Before bulk import, pre-split the collection
# This distributes empty chunks across shards

# Calculate split points for even distribution
def calculate_split_points(min_val, max_val, num_chunks):
    """Calculate split points for hashed sharding."""
    range_size = max_val - min_val
    chunk_size = range_size // num_chunks
    return [min_val + (i * chunk_size) for i in range(1, num_chunks)]

# Pre-split command (run before bulk load)
"""
# For hashed shard key on _id
# Split into 256 chunks (adjust based on shard count)
for i in range(256):
    splitPoint = NumberLong(i * (MaxKey / 256))
    db.admin.command({split: "mydb.collection", middle: {_id: splitPoint}})
"""

# Disable balancer during bulk load
"""
sh.disableBalancing("mydb.collection")
"""

# Bulk load with ordered=False for parallelism
async def bulk_import_data(documents: list, batch_size: int = 5000):
    """Import data in batches with balancer disabled."""
    for i in range(0, len(documents), batch_size):
        batch = documents[i:i + batch_size]
        await db.collection.insert_many(batch, ordered=False)

# Re-enable balancer after load
"""
sh.enableBalancing("mydb.collection")
"""

# For time-series data, pre-split by time ranges
"""
# Monthly chunks for orders
sh.splitAt("mydb.orders", {created_at: ISODate("2024-02-01")})
sh.splitAt("mydb.orders", {created_at: ISODate("2024-03-01")})
sh.splitAt("mydb.orders", {created_at: ISODate("2024-04-01")})
"""
```

---

# Operations & Maintenance

## 42. Use WiredTiger Storage Engine

Ensure you're using the WiredTiger storage engine (default since MongoDB 3.2) for compression and better concurrency.

```python
# Check current storage engine
async def check_storage_engine():
    server_status = await db.admin.command("serverStatus")
    return server_status.get("storageEngine", {}).get("name")

# WiredTiger benefits:
# - Document-level locking (vs collection-level in MMAPv1)
# - Built-in compression
# - Better memory management
# - Checkpoint-based durability

# WiredTiger configuration (mongod.conf)
"""
storage:
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 4  # Adjust based on available RAM
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy  # or zstd for better ratio
    indexConfig:
      prefixCompression: true
"""

# Per-collection compression settings
await db.create_collection(
    "logs",
    storageEngine={
        "wiredTiger": {
            "configString": "block_compressor=zstd"
        }
    }
)

# Check compression stats
async def get_compression_stats(collection_name: str):
    stats = await db.command("collStats", collection_name)
    return {
        "storage_size": stats["storageSize"],
        "data_size": stats["size"],
        "compression_ratio": stats["size"] / stats["storageSize"] if stats["storageSize"] > 0 else 0
    }
```

---

## 43. Enable and Tune Compression

Use snappy (default, fast) or zstd (better ratio) for compression based on your needs.

```python
# Compression comparison:
# snappy: Fast compression/decompression, moderate ratio (~2-4x)
# zstd: Slower but better ratio (~4-8x), good for cold data
# zlib: Legacy, between snappy and zstd
# none: No compression (rarely needed)

# Collection with zstd compression (better for archival data)
await db.create_collection(
    "historical_logs",
    storageEngine={
        "wiredTiger": {
            "configString": "block_compressor=zstd,zstd_compression_level=6"
        }
    }
)

# Collection with snappy (default, good for hot data)
await db.create_collection(
    "active_sessions",
    storageEngine={
        "wiredTiger": {
            "configString": "block_compressor=snappy"
        }
    }
)

# Index compression is always prefix compression
# Configure in mongod.conf:
"""
storage:
  wiredTiger:
    indexConfig:
      prefixCompression: true
"""

# Monitor compression effectiveness
async def compression_report():
    collections = await db.list_collection_names()
    report = []

    for coll_name in collections:
        stats = await db.command("collStats", coll_name)
        report.append({
            "collection": coll_name,
            "data_size_mb": stats["size"] / 1024 / 1024,
            "storage_size_mb": stats["storageSize"] / 1024 / 1024,
            "compression_ratio": round(stats["size"] / max(stats["storageSize"], 1), 2)
        })

    return sorted(report, key=lambda x: x["data_size_mb"], reverse=True)
```

---

## 44. Monitor Working Set Size

Ensure your frequently accessed data (working set) fits in RAM for optimal performance.

```python
# Check server memory stats
async def get_memory_stats():
    server_status = await db.admin.command("serverStatus")
    wt = server_status.get("wiredTiger", {})

    cache = wt.get("cache", {})
    return {
        "cache_size_configured_gb": cache.get("maximum bytes configured", 0) / 1024**3,
        "cache_used_gb": cache.get("bytes currently in the cache", 0) / 1024**3,
        "cache_dirty_gb": cache.get("tracked dirty bytes in the cache", 0) / 1024**3,
        "pages_read_into_cache": cache.get("pages read into cache", 0),
        "pages_evicted": cache.get("pages evicted by application threads", 0),
        "cache_hit_ratio": None  # Calculate from application metrics
    }

# Calculate working set estimate
async def estimate_working_set():
    """Estimate working set from recent query patterns."""
    # Get all collection stats
    collections = await db.list_collection_names()
    total_size = 0
    hot_size = 0

    for coll_name in collections:
        stats = await db.command("collStats", coll_name)
        total_size += stats.get("size", 0)

        # Estimate "hot" data (adjust based on your patterns)
        # Example: Recent 20% of data
        hot_size += stats.get("size", 0) * 0.2

    return {
        "total_data_gb": total_size / 1024**3,
        "estimated_working_set_gb": hot_size / 1024**3,
        "recommendation": "Ensure cache > working set for best performance"
    }

# Working set monitoring alert
async def check_working_set_health():
    memory = await get_memory_stats()
    working_set = await estimate_working_set()

    cache_gb = memory["cache_size_configured_gb"]
    ws_gb = working_set["estimated_working_set_gb"]

    if ws_gb > cache_gb * 0.8:
        return {
            "status": "WARNING",
            "message": f"Working set ({ws_gb:.1f}GB) approaching cache size ({cache_gb:.1f}GB)",
            "recommendation": "Consider increasing cache size or optimizing queries"
        }

    return {"status": "OK", "cache_gb": cache_gb, "working_set_gb": ws_gb}
```

---

## 45. Implement Connection Pooling

Properly configure connection pools to balance performance and resource usage.

```python
from motor.motor_asyncio import AsyncIOMotorClient

# Production connection configuration
def create_mongo_client(connection_string: str) -> AsyncIOMotorClient:
    """Create MongoDB client with optimized connection pool."""
    return AsyncIOMotorClient(
        connection_string,
        # Connection pool settings
        maxPoolSize=100,           # Max connections per server
        minPoolSize=10,            # Min connections maintained
        maxIdleTimeMS=30000,       # Close idle connections after 30s
        waitQueueTimeoutMS=5000,   # Timeout waiting for connection

        # Server selection
        serverSelectionTimeoutMS=5000,
        connectTimeoutMS=10000,
        socketTimeoutMS=30000,

        # Read/Write settings
        retryWrites=True,
        retryReads=True,

        # Compression
        compressors=["zstd", "snappy", "zlib"],

        # Application name for monitoring
        appName="my-application"
    )

# Connection pool sizing guidelines:
# - API servers: maxPoolSize = expected_concurrent_requests * 1.5
# - Background workers: maxPoolSize = num_workers * 2
# - Batch jobs: maxPoolSize = batch_parallelism

# Monitor connection pool
async def monitor_connection_pool(client: AsyncIOMotorClient):
    """Get connection pool statistics."""
    # Note: Motor/PyMongo doesn't expose pool stats directly
    # Use server monitoring for insights

    server_status = await client.admin.command("serverStatus")
    connections = server_status.get("connections", {})

    return {
        "current": connections.get("current", 0),
        "available": connections.get("available", 0),
        "total_created": connections.get("totalCreated", 0)
    }

# Graceful shutdown
async def shutdown_mongo_client(client: AsyncIOMotorClient):
    """Properly close all connections on shutdown."""
    client.close()
```

---

## 46. Use Aggregation Pipeline Efficiently

Optimize aggregation pipelines by filtering early and using indexes.

```python
# BAD: Filter late in pipeline (processes all documents)
pipeline_bad = [
    {"$lookup": {...}},
    {"$unwind": "$items"},
    {"$group": {...}},
    {"$match": {"status": "active"}}  # Filter at the end
]

# GOOD: Filter early (uses index, fewer documents processed)
pipeline_good = [
    {"$match": {"status": "active", "created_at": {"$gte": cutoff}}},  # Filter first
    {"$lookup": {...}},
    {"$unwind": "$items"},
    {"$group": {...}}
]

# Use $limit and $skip early when possible
pipeline_with_limit = [
    {"$match": {"status": "active"}},
    {"$sort": {"created_at": -1}},
    {"$limit": 100},  # Limit early, not after expensive stages
    {"$lookup": {...}}
]

# Project only needed fields early
pipeline_with_projection = [
    {"$match": {"status": "active"}},
    {"$project": {  # Reduce document size before processing
        "user_id": 1,
        "total": 1,
        "items.product_id": 1,
        "items.quantity": 1
    }},
    {"$unwind": "$items"},
    {"$group": {...}}
]

# Use allowDiskUse for large pipelines
result = await db.orders.aggregate(
    large_pipeline,
    allowDiskUse=True
).to_list(None)

# Explain aggregation to check index usage
explain = await db.orders.aggregate(pipeline, explain=True).to_list(1)
```

---

## 47. Implement Proper Error Handling

Handle MongoDB-specific errors appropriately for retries and user feedback.

```python
from pymongo.errors import (
    DuplicateKeyError,
    BulkWriteError,
    ServerSelectionTimeoutError,
    NetworkTimeout,
    WriteConcernError,
    WriteError
)

async def safe_insert(collection, document: dict) -> dict:
    """Insert with proper error handling."""
    try:
        result = await collection.insert_one(document)
        return {"success": True, "id": result.inserted_id}

    except DuplicateKeyError as e:
        # Handle unique constraint violation
        key = e.details.get("keyValue", {})
        return {"success": False, "error": "duplicate", "field": list(key.keys())[0]}

    except WriteConcernError as e:
        # Write succeeded but didn't meet write concern
        # May need to verify or retry
        return {"success": False, "error": "write_concern", "details": str(e)}

    except NetworkTimeout:
        # Network issue - may need retry
        return {"success": False, "error": "timeout", "retry": True}

    except ServerSelectionTimeoutError:
        # Can't reach any server
        return {"success": False, "error": "server_unavailable", "retry": True}

async def safe_bulk_write(collection, operations: list) -> dict:
    """Bulk write with detailed error handling."""
    try:
        result = await collection.bulk_write(operations, ordered=False)
        return {
            "success": True,
            "inserted": result.inserted_count,
            "modified": result.modified_count,
            "deleted": result.deleted_count
        }

    except BulkWriteError as e:
        # Some operations succeeded, some failed
        return {
            "success": False,
            "partial": True,
            "inserted": e.details.get("nInserted", 0),
            "errors": [
                {"index": err["index"], "code": err["code"], "message": err["errmsg"]}
                for err in e.details.get("writeErrors", [])
            ]
        }

# Retry decorator for transient failures
import asyncio
from functools import wraps

def with_retry(max_retries: int = 3, backoff: float = 0.5):
    """Decorator for retrying MongoDB operations."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            last_error = None
            for attempt in range(max_retries):
                try:
                    return await func(*args, **kwargs)
                except (NetworkTimeout, ServerSelectionTimeoutError) as e:
                    last_error = e
                    if attempt < max_retries - 1:
                        await asyncio.sleep(backoff * (2 ** attempt))
            raise last_error
        return wrapper
    return decorator

@with_retry(max_retries=3)
async def fetch_user(user_id: ObjectId):
    return await db.users.find_one({"_id": user_id})
```

---

## 48. Use Transactions for Multi-Document Operations

Use transactions when you need atomic multi-document updates (requires replica set).

```python
async def transfer_funds(
    from_account_id: ObjectId,
    to_account_id: ObjectId,
    amount: Decimal,
    db
) -> dict:
    """Transfer funds atomically between accounts."""
    async with await db.client.start_session() as session:
        async with session.start_transaction():
            # Debit source account
            result = await db.accounts.update_one(
                {
                    "_id": from_account_id,
                    "balance": {"$gte": amount}  # Check balance
                },
                {"$inc": {"balance": -amount}},
                session=session
            )

            if result.modified_count == 0:
                raise ValueError("Insufficient funds")

            # Credit destination account
            await db.accounts.update_one(
                {"_id": to_account_id},
                {"$inc": {"balance": amount}},
                session=session
            )

            # Create transaction record
            await db.transactions.insert_one(
                {
                    "from": from_account_id,
                    "to": to_account_id,
                    "amount": Decimal128(amount),
                    "timestamp": datetime.utcnow(),
                    "status": "completed"
                },
                session=session
            )

            # Transaction commits when exiting the context manager

    return {"status": "success", "amount": str(amount)}

# Transaction best practices:
# 1. Keep transactions short (< 60 seconds)
# 2. Limit to documents that need atomicity
# 3. Use write concern "majority" for durability
# 4. Handle TransientTransactionError with retry

from pymongo.errors import PyMongoError

async def run_transaction_with_retry(coro_func, *args, **kwargs):
    """Run a transaction with automatic retry on transient errors."""
    while True:
        try:
            return await coro_func(*args, **kwargs)
        except PyMongoError as e:
            if e.has_error_label("TransientTransactionError"):
                continue  # Retry
            raise
```

---

## 49. Implement Data Archival Strategy

Plan for data lifecycle management to keep active collections performant.

```python
from datetime import datetime, timedelta

async def archive_old_orders(cutoff_days: int = 365):
    """Move old orders to archive collection."""
    cutoff_date = datetime.utcnow() - timedelta(days=cutoff_days)

    # Find orders to archive
    old_orders = await db.orders.find({
        "created_at": {"$lt": cutoff_date},
        "status": {"$in": ["completed", "cancelled"]}
    }).to_list(None)

    if not old_orders:
        return {"archived": 0}

    # Insert into archive (with different compression/storage)
    await db.orders_archive.insert_many(old_orders)

    # Delete from active collection
    ids_to_delete = [o["_id"] for o in old_orders]
    await db.orders.delete_many({"_id": {"$in": ids_to_delete}})

    return {"archived": len(old_orders)}

# Time-series collection with automatic archival (MongoDB 5.0+)
await db.create_collection(
    "metrics",
    timeseries={
        "timeField": "timestamp",
        "metaField": "source",
        "granularity": "minutes"
    },
    expireAfterSeconds=86400 * 90  # Auto-delete after 90 days
)

# Separate hot and cold collections
class OrderRepository:
    def __init__(self, db):
        self.active = db.orders  # Hot: SSD, frequent access
        self.archive = db.orders_archive  # Cold: HDD, infrequent access

    async def find_order(self, order_id: ObjectId):
        """Search active first, then archive."""
        order = await self.active.find_one({"_id": order_id})
        if not order:
            order = await self.archive.find_one({"_id": order_id})
        return order

    async def search_orders(self, query: dict, include_archive: bool = False):
        """Search with optional archive inclusion."""
        results = await self.active.find(query).to_list(100)

        if include_archive and len(results) < 100:
            archive_results = await self.archive.find(query).to_list(100 - len(results))
            results.extend(archive_results)

        return results
```

---

## 50. Monitor and Alert on Key Metrics

Set up monitoring for essential MongoDB health indicators.

```python
import asyncio
from datetime import datetime

class MongoDBMonitor:
    """Monitor MongoDB health metrics."""

    def __init__(self, db):
        self.db = db
        self.thresholds = {
            "replication_lag_seconds": 10,
            "connections_percent": 80,
            "cache_hit_ratio": 0.9,
            "queue_length": 100,
            "slow_query_ms": 100
        }

    async def get_replica_status(self):
        """Check replication health."""
        try:
            status = await self.db.admin.command("replSetGetStatus")
            members = status.get("members", [])

            primary = next((m for m in members if m["stateStr"] == "PRIMARY"), None)
            secondaries = [m for m in members if m["stateStr"] == "SECONDARY"]

            max_lag = 0
            if primary:
                primary_optime = primary.get("optime", {}).get("ts", {})
                for sec in secondaries:
                    sec_optime = sec.get("optime", {}).get("ts", {})
                    lag = (primary_optime.time - sec_optime.time) if hasattr(primary_optime, 'time') else 0
                    max_lag = max(max_lag, lag)

            return {
                "healthy": max_lag < self.thresholds["replication_lag_seconds"],
                "max_lag_seconds": max_lag,
                "primary": primary["name"] if primary else None,
                "secondary_count": len(secondaries)
            }
        except Exception as e:
            return {"healthy": False, "error": str(e)}

    async def get_connection_stats(self):
        """Monitor connection pool usage."""
        status = await self.db.admin.command("serverStatus")
        connections = status.get("connections", {})

        current = connections.get("current", 0)
        available = connections.get("available", 0)
        total = current + available
        percent_used = (current / total * 100) if total > 0 else 0

        return {
            "healthy": percent_used < self.thresholds["connections_percent"],
            "current": current,
            "available": available,
            "percent_used": round(percent_used, 1)
        }

    async def get_operation_stats(self):
        """Monitor operation performance."""
        status = await self.db.admin.command("serverStatus")
        opcounters = status.get("opcounters", {})

        return {
            "insert": opcounters.get("insert", 0),
            "query": opcounters.get("query", 0),
            "update": opcounters.get("update", 0),
            "delete": opcounters.get("delete", 0),
            "getmore": opcounters.get("getmore", 0),
            "command": opcounters.get("command", 0)
        }

    async def get_slow_queries(self, min_ms: int = 100):
        """Get recent slow queries from profiler."""
        # Requires profiling enabled: db.setProfilingLevel(1, {slowms: 100})
        slow = await self.db.system.profile.find({
            "millis": {"$gte": min_ms}
        }).sort("ts", -1).limit(10).to_list(10)

        return [
            {
                "namespace": q.get("ns"),
                "operation": q.get("op"),
                "duration_ms": q.get("millis"),
                "timestamp": q.get("ts"),
                "query": q.get("command", {}).get("filter", {})
            }
            for q in slow
        ]

    async def health_check(self) -> dict:
        """Comprehensive health check."""
        replica = await self.get_replica_status()
        connections = await self.get_connection_stats()
        ops = await self.get_operation_stats()

        overall_healthy = replica["healthy"] and connections["healthy"]

        return {
            "timestamp": datetime.utcnow().isoformat(),
            "healthy": overall_healthy,
            "replication": replica,
            "connections": connections,
            "operations": ops,
            "alerts": [
                alert for alert in [
                    "High replication lag" if not replica["healthy"] else None,
                    "Connection pool exhaustion" if not connections["healthy"] else None
                ] if alert
            ]
        }

# Usage
monitor = MongoDBMonitor(db)

async def periodic_health_check():
    """Run health check every minute."""
    while True:
        health = await monitor.health_check()

        if not health["healthy"]:
            # Send alert
            print(f"ALERT: MongoDB unhealthy - {health['alerts']}")

        await asyncio.sleep(60)
```

---

# Quick Reference

```python
# === EMBEDDING vs REFERENCING ===
# Embed: One-to-few, always accessed together, atomic updates needed
# Reference: One-to-many/squillions, independent access, unbounded growth

# === INDEX CREATION ===
# ESR Rule: Equality, Sort, Range
db.collection.create_index([("status", 1), ("created_at", -1)])

# Partial index (saves RAM)
db.collection.create_index(
    [("field", 1)],
    partialFilterExpression={"status": "active"}
)

# TTL index (auto-delete)
db.collection.create_index("expires_at", expireAfterSeconds=0)

# === QUERY OPTIMIZATION ===
# Always project needed fields
await db.users.find({}, {"name": 1, "email": 1})

# Avoid $ne, use $in with explicit values
await db.users.find({"status": {"$in": ["pending", "active"]}})

# Use explain() to verify index usage
await db.collection.find(query).explain()

# === BULK OPERATIONS ===
from pymongo import UpdateOne
operations = [UpdateOne({"_id": id}, {"$set": data}) for id, data in items]
await db.collection.bulk_write(operations, ordered=False)

# === TRANSACTIONS ===
async with await client.start_session() as session:
    async with session.start_transaction():
        await db.coll1.update_one(..., session=session)
        await db.coll2.insert_one(..., session=session)

# === AGGREGATION ===
pipeline = [
    {"$match": {...}},   # Filter first (uses index)
    {"$project": {...}}, # Reduce fields early
    {"$group": {...}},   # Expensive operations later
]
await db.collection.aggregate(pipeline, allowDiskUse=True)
```

---

# Schema Design Checklist

Before deploying any schema:

- [ ] **Access Patterns**: Schema optimized for your most frequent queries?
- [ ] **Embedding**: One-to-few relationships embedded appropriately?
- [ ] **References**: One-to-many/squillions use references?
- [ ] **Bounded Arrays**: No unbounded arrays that could hit 16MB limit?
- [ ] **Indexes**: Compound indexes follow ESR rule?
- [ ] **Covered Queries**: Common queries can be satisfied by indexes alone?
- [ ] **Projections**: Queries return only needed fields?
- [ ] **Shard Key**: If sharding, key has high cardinality and even distribution?
- [ ] **Write Concern**: Appropriate durability level for data criticality?
- [ ] **Schema Version**: Version field for future migrations?
- [ ] **TTL/Archival**: Plan for data lifecycle and cleanup?
- [ ] **Monitoring**: Key metrics being tracked and alerted?
