from django.http import JsonResponse


def healthz(request):
    """Return a lightweight response for container and load-balancer probes."""
    return JsonResponse({"status": "ok"})
