output "database_arn" {
  value = aws_elasticache_cluster.redis.cache_nodes.0.address
}
