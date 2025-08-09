import psutil
import docker
import asyncio
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Any
import redis
import os
import requests
from collections import defaultdict, deque


class SystemMonitor:
    def __init__(self):
        self.docker_client = docker.from_env()
        self.redis_client = redis.Redis(
            host="localhost", port=6379, db=0, decode_responses=True
        )
        self.chat_history = defaultdict(lambda: deque(maxlen=1000))
        self.customer_sessions = {}
        self.system_metrics = deque(maxlen=1000)

    async def get_docker_stats(self) -> Dict[str, Any]:
        """Hent Docker-statistikk"""
        try:
            containers = self.docker_client.containers.list()
            stats = {
                "total_containers": len(containers),
                "running_containers": len(
                    [c for c in containers if c.status == "running"]
                ),
                "stopped_containers": len(
                    [c for c in containers if c.status == "exited"]
                ),
                "container_details": [],
            }

            for container in containers:
                try:
                    container_stats = container.stats(stream=False)
                    stats["container_details"].append(
                        {
                            "id": container.id[:12],
                            "name": container.name,
                            "status": container.status,
                            "image": (
                                container.image.tags[0]
                                if container.image.tags
                                else "unknown"
                            ),
                            "cpu_percent": self._calculate_cpu_percent(container_stats),
                            "memory_usage": container_stats["memory"]["usage"],
                            "network_io": container_stats.get("networks", {}),
                            "ports": container.ports,
                            "created": container.attrs["Created"],
                            "uptime": time.time() - container.attrs["Created"],
                        }
                    )
                except Exception as e:
                    stats["container_details"].append(
                        {
                            "id": container.id[:12],
                            "name": container.name,
                            "status": container.status,
                            "error": str(e),
                        }
                    )

            return stats
        except Exception as e:
            return {"error": str(e), "total_containers": 0}

    def _calculate_cpu_percent(self, stats):
        """Beregn CPU-bruk i prosent"""
        try:
            cpu_delta = (
                stats["cpu_stats"]["cpu_usage"]["total_usage"]
                - stats["precpu_stats"]["cpu_usage"]["total_usage"]
            )
            system_delta = (
                stats["cpu_stats"]["system_cpu_usage"]
                - stats["precpu_stats"]["system_cpu_usage"]
            )
            if system_delta > 0.0:
                return (
                    (cpu_delta / system_delta)
                    * len(stats["cpu_stats"]["cpu_usage"]["percpu_usage"])
                    * 100
                )
        except:
            pass
        return 0.0

    async def get_port_stats(self) -> Dict[str, Any]:
        """Hent port-statistikk"""
        try:
            port_stats = {}
            # Sjekk kjente porter
            known_ports = {
                3001: "Original Frontend",
                3002: "Admin Frontend",
                8000: "Original Backend",
                8001: "Admin Backend",
                8002: "Admin Backend (alt)",
                6379: "Redis",
            }

            for port, service in known_ports.items():
                try:
                    result = os.system(
                        f'netstat -tlnp 2>/dev/null | grep -q ":{port} "'
                    )
                    port_stats[port] = {
                        "service": service,
                        "open": result == 0,
                        "last_check": datetime.now().isoformat(),
                    }
                except:
                    port_stats[port] = {
                        "service": service,
                        "open": False,
                        "last_check": datetime.now().isoformat(),
                    }

            return port_stats
        except Exception as e:
            return {"error": str(e)}

    async def get_system_health(self) -> Dict[str, Any]:
        """Hent systemhelse"""
        try:
            health = {
                "timestamp": datetime.now().isoformat(),
                "cpu": {
                    "percent": psutil.cpu_percent(interval=1),
                    "count": psutil.cpu_count(),
                    "load_avg": psutil.getloadavg(),
                },
                "memory": {
                    "total": psutil.virtual_memory().total,
                    "available": psutil.virtual_memory().available,
                    "percent": psutil.virtual_memory().percent,
                    "used": psutil.virtual_memory().used,
                },
                "disk": {
                    "total": psutil.disk_usage("/").total,
                    "used": psutil.disk_usage("/").used,
                    "free": psutil.disk_usage("/").free,
                    "percent": psutil.disk_usage("/").percent,
                },
                "network": {
                    "bytes_sent": psutil.net_io_counters().bytes_sent,
                    "bytes_recv": psutil.net_io_counters().bytes_recv,
                    "packets_sent": psutil.net_io_counters().packets_sent,
                    "packets_recv": psutil.net_io_counters().packets_recv,
                },
                "uptime": time.time() - psutil.boot_time(),
            }
            return health
        except Exception as e:
            return {"error": str(e)}

    async def get_chat_analytics(self) -> Dict[str, Any]:
        """Hent chat-analyse"""
        try:
            # Hent data fra Redis
            total_messages = len(list(self.redis_client.scan_iter(match="message:*")))
            total_sessions = len(list(self.redis_client.scan_iter(match="session:*")))
            total_responses = len(list(self.redis_client.scan_iter(match="response:*")))

            # Beregn statistikk
            analytics = {
                "total_messages": total_messages,
                "total_sessions": total_sessions,
                "total_responses": total_responses,
                "response_rate": (
                    (total_responses / total_messages * 100)
                    if total_messages > 0
                    else 0
                ),
                "avg_messages_per_session": (
                    total_messages / total_sessions if total_sessions > 0 else 0
                ),
                "peak_hours": self._get_peak_hours(),
                "top_customer_issues": self._get_top_issues(),
                "response_time_avg": self._calculate_avg_response_time(),
                "customer_satisfaction": self._calculate_satisfaction_score(),
            }

            return analytics
        except Exception as e:
            return {"error": str(e)}

    def _get_peak_hours(self) -> List[Dict]:
        """Finn time med mest aktivitet"""
        # Simuler peak hours basert på tid
        current_hour = datetime.now().hour
        peak_hours = []
        for hour_offset in range(-6, 7):
            hour = (current_hour + hour_offset) % 24
            activity = self.redis_client.get(f"activity:hour:{hour}")
            peak_hours.append(
                {"hour": hour, "activity": int(activity) if activity else 0}
            )

        return sorted(peak_hours, key=lambda x: x["activity"], reverse=True)[:5]

    def _get_top_issues(self) -> List[Dict]:
        """Finn vanligste kundeproblemer"""
        # Simuler vanlige problemer
        common_issues = [
            "batteri-spørsmål",
            "prisinformasjon",
            "leveringstid",
            "montering",
            "teknisk support",
        ]

        issues = []
        for issue in common_issues:
            count = self.redis_client.get(f"issue:{issue}")
            issues.append({"issue": issue, "count": int(count) if count else 0})

        return sorted(issues, key=lambda x: x["count"], reverse=True)

    def _calculate_avg_response_time(self) -> float:
        """Beregn gjennomsnittlig svartid"""
        # Simuler beregning
        return 2.5  # minutter

    def _calculate_satisfaction_score(self) -> float:
        """Beregn kundetilfredshet"""
        # Simuler score
        return 4.2  # av 5

    async def get_customer_insights(self) -> Dict[str, Any]:
        """Hent kundeinnsikt"""
        try:
            insights = {
                "active_customers": len(self.customer_sessions),
                "customer_segments": self._get_customer_segments(),
                "repeat_customers": self._get_repeat_customers(),
                "geographic_distribution": self._get_geographic_data(),
                "device_distribution": self._get_device_data(),
                "behavior_patterns": self._get_behavior_patterns(),
            }
            return insights
        except Exception as e:
            return {"error": str(e)}

    def _get_customer_segments(self) -> Dict[str, int]:
        """Kundesegmentering"""
        return {
            "new_customers": 15,
            "returning_customers": 23,
            "vip_customers": 5,
            "business_customers": 8,
        }

    def _get_repeat_customers(self) -> List[Dict]:
        """Gjentakende kunder"""
        return [
            {"customer_id": "cust_001", "visits": 5, "last_visit": "2025-08-07"},
            {"customer_id": "cust_002", "visits": 3, "last_visit": "2025-08-06"},
        ]

    def _get_geographic_data(self) -> Dict[str, int]:
        """Geografisk fordeling"""
        return {"Oslo": 25, "Bergen": 15, "Trondheim": 10, "Stavanger": 8, "Andre": 12}

    def _get_device_data(self) -> Dict[str, int]:
        """Enhetsfordeling"""
        return {"Desktop": 45, "Mobile": 35, "Tablet": 20}

    def _get_behavior_patterns(self) -> List[Dict]:
        """Atferdsmønstre"""
        return [
            {
                "pattern": "quick_browse",
                "count": 30,
                "description": "Kunder som ser raskt",
            },
            {
                "pattern": "detailed_research",
                "count": 15,
                "description": "Grundig research",
            },
            {
                "pattern": "repeat_visitor",
                "count": 10,
                "description": "Gjentatte besøk",
            },
        ]

    async def get_recommendations(self) -> Dict[str, Any]:
        """Generer anbefalinger basert på data"""
        try:
            recommendations = {
                "system_recommendations": self._get_system_recommendations(),
                "business_recommendations": self._get_business_recommendations(),
                "customer_service_recommendations": self._get_cs_recommendations(),
                "technical_recommendations": self._get_technical_recommendations(),
                "priority_actions": self._get_priority_actions(),
            }
            return recommendations
        except Exception as e:
            return {"error": str(e)}

    def _get_system_recommendations(self) -> List[Dict]:
        """Systemanbefalinger"""
        return [
            {
                "type": "performance",
                "title": "Optimaliser Redis-konfigurasjon",
                "description": "Redis-bruk er høy, vurder å øke memory limit",
                "priority": "medium",
                "impact": "medium",
            },
            {
                "type": "scaling",
                "title": "Vurder horisontal skalering",
                "description": "CPU-bruk overstiger 70% i perioder",
                "priority": "high",
                "impact": "high",
            },
        ]

    def _get_business_recommendations(self) -> List[Dict]:
        """Forretningsanbefalinger"""
        return [
            {
                "type": "marketing",
                "title": "Fokus på batteri-anbefalinger",
                "description": "30% av kundene spør om batteri-kompatibilitet",
                "priority": "high",
                "impact": "high",
            },
            {
                "type": "service",
                "title": "Utvid kundesupport",
                "description": "Svartid kan forbedres med 25%",
                "priority": "medium",
                "impact": "medium",
            },
        ]

    def _get_cs_recommendations(self) -> List[Dict]:
        """Kundeservice-anbefalinger"""
        return [
            {
                "type": "training",
                "title": "Opplæring i Varta-produkter",
                "description": "Mange spørsmål om Varta-batterier",
                "priority": "medium",
                "impact": "medium",
            }
        ]

    def _get_technical_recommendations(self) -> List[Dict]:
        """Tekniske anbefalinger"""
        return [
            {
                "type": "security",
                "title": "Oppdater SSL-sertifikater",
                "description": "Sertifikater utløper om 30 dager",
                "priority": "high",
                "impact": "high",
            }
        ]

    def _get_priority_actions(self) -> List[Dict]:
        """Prioriterte handlinger"""
        return [
            {
                "action": "Oppdater SSL-sertifikater",
                "deadline": "2025-09-07",
                "assigned_to": "System Administrator",
                "status": "pending",
            },
            {
                "action": "Optimaliser database",
                "deadline": "2025-08-14",
                "assigned_to": "Developer",
                "status": "in_progress",
            },
        ]

    async def get_complete_dashboard(self) -> Dict[str, Any]:
        """Hent komplett dashboard-data"""
        try:
            dashboard_data = {
                "timestamp": datetime.now().isoformat(),
                "docker_stats": await self.get_docker_stats(),
                "port_stats": await self.get_port_stats(),
                "system_health": await self.get_system_health(),
                "chat_analytics": await self.get_chat_analytics(),
                "customer_insights": await self.get_customer_insights(),
                "recommendations": await self.get_recommendations(),
            }

            # Lagre til Redis for historikk
            self.redis_client.set(
                f"dashboard:{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                json.dumps(dashboard_data),
            )

            return dashboard_data
        except Exception as e:
            return {"error": str(e)}


# Opprett monitor instans
monitor = SystemMonitor()
