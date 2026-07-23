"""HTTP support for this app: one place for the web server setup, route list, JSON answers, and
security around certain URLs.

Subfolders split the work: ``contracts`` is the shared “shape” feature code can rely on;
``response`` builds JSON bodies; ``service`` holds the route list and how requests are sent to the
right code; ``middleware`` runs small checks before some handlers. The normal entry for starting
the app is ``createHttpHandler`` in ``http_app``.
"""
