"""Load test for the Bookmarks sample API (GAP-012, ADR-0062).

Each simulated user saves bookmarks, reads them back and lists a page, as a person using a bookmarks app would. The
shared performance workflow runs it headless against the API it started, from this folder, so locust.conf sets the
load and load-budget.json the limits that tools/Test-LoadBudget.ps1 checks. Every endpoint needs a bearer token
(SEC-007); the workflow issues one for this run only and hands it over as LOAD_TEST_TOKEN.
"""

import os
import random
import uuid

from locust import HttpUser, between, task


class BookmarkUser(HttpUser):
    wait_time = between(0.1, 0.5)

    def on_start(self):
        self.client.headers["Authorization"] = f"Bearer {os.environ['LOAD_TEST_TOKEN']}"
        self.saved = []

    @task(1)
    def save(self):
        # A new URL each time: the same URL twice is a 409 Conflict, which Locust would count as a failure.
        bookmark = {"url": f"https://example.com/articles/{uuid.uuid4()}", "title": "Load test"}
        with self.client.post("/bookmarks", json=bookmark, catch_response=True) as response:
            if response.status_code == 201:
                self.saved.append(response.json()["id"])
            else:
                response.failure(f"expected 201 Created, got {response.status_code}")

    @task(3)
    def read(self):
        if self.saved:
            # One name for every id, so the stats show one row for this request, which load-budget.json can name.
            self.client.get(f"/bookmarks/{random.choice(self.saved)}", name="/bookmarks/[id]")

    @task(3)
    def list_page(self):
        self.client.get("/bookmarks?limit=25", name="/bookmarks")
