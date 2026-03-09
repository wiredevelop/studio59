-- MariaDB dump 10.19  Distrib 10.4.32-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: studio59
-- ------------------------------------------------------
-- Server version	10.4.32-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `studio59`
--

/*!40000 DROP DATABASE IF EXISTS `studio59`*/;

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `studio59` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;

USE `studio59`;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `audit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `entity_type` varchar(100) DEFAULT NULL,
  `entity_id` bigint(20) unsigned DEFAULT NULL,
  `meta` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`meta`)),
  `ip` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `audit_logs_user_id_foreign` (`user_id`),
  KEY `audit_logs_action_created_at_index` (`action`,`created_at`),
  CONSTRAINT `audit_logs_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
INSERT INTO `audit_logs` VALUES (1,1,'guest.order.created','App\\Models\\Order',1,'{\"event_id\":1,\"order_code\":\"S59-A7ONZOIM\",\"payment_method\":\"cash\",\"photo_count\":4}','127.0.0.1','2026-03-03 23:23:34','2026-03-03 23:23:34'),(2,1,'guest.order.created','App\\Models\\Order',2,'{\"event_id\":1,\"order_code\":\"S59-QQSK0TH0\",\"payment_method\":\"cash\",\"photo_count\":8}','127.0.0.1','2026-03-03 23:29:36','2026-03-03 23:29:36'),(3,1,'order.mark_paid','App\\Models\\Order',2,'{\"order_code\":\"S59-QQSK0TH0\"}','127.0.0.1','2026-03-03 23:30:00','2026-03-03 23:30:00'),(4,1,'order.mark_delivered','App\\Models\\Order',2,'{\"order_code\":\"S59-QQSK0TH0\"}','127.0.0.1','2026-03-03 23:30:06','2026-03-03 23:30:06'),(5,NULL,'guest.order.created','App\\Models\\Order',3,'{\"event_id\":1,\"order_code\":\"S59-YVPDTWQE\",\"payment_method\":\"cash\",\"photo_count\":6}','127.0.0.1','2026-03-03 23:39:40','2026-03-03 23:39:40'),(6,1,'order.mark_paid','App\\Models\\Order',3,'{\"order_code\":\"S59-YVPDTWQE\"}','127.0.0.1','2026-03-03 23:39:58','2026-03-03 23:39:58'),(7,1,'order.download_link.send','App\\Models\\Order',3,'{\"sent\":true}','127.0.0.1','2026-03-03 23:40:16','2026-03-03 23:40:16'),(8,1,'order.download_link.send','App\\Models\\Order',3,'{\"sent\":true}','127.0.0.1','2026-03-03 23:46:28','2026-03-03 23:46:28'),(9,1,'order.download_link.send','App\\Models\\Order',3,'{\"sent\":true}','127.0.0.1','2026-03-03 23:49:08','2026-03-03 23:49:08'),(10,1,'api.auth.login.success',NULL,NULL,'{\"user_id\":1}','127.0.0.1','2026-03-04 00:10:00','2026-03-04 00:10:00'),(11,1,'api.auth.login.success',NULL,NULL,'{\"user_id\":1}','127.0.0.1','2026-03-04 00:10:23','2026-03-04 00:10:23'),(12,1,'order.mark_paid','App\\Models\\Order',5,'{\"order_code\":\"S59-6GLZSGU0\"}','127.0.0.1','2026-03-04 00:37:28','2026-03-04 00:37:28'),(13,1,'order.download_link.send','App\\Models\\Order',5,'{\"sent\":true}','127.0.0.1','2026-03-04 00:37:36','2026-03-04 00:37:36'),(14,1,'order.mark_paid','App\\Models\\Order',6,'{\"order_code\":\"S59-GWNYIX0U\"}','127.0.0.1','2026-03-04 00:42:52','2026-03-04 00:42:52'),(15,1,'api.auth.login.success',NULL,NULL,'{\"user_id\":1}','127.0.0.1','2026-03-04 00:43:48','2026-03-04 00:43:48'),(16,1,'api.order.mark_delivered','App\\Models\\Order',3,'{\"order_code\":\"S59-YVPDTWQE\"}','127.0.0.1','2026-03-04 00:44:09','2026-03-04 00:44:09'),(17,1,'api.order.mark_delivered','App\\Models\\Order',5,'{\"order_code\":\"S59-6GLZSGU0\"}','127.0.0.1','2026-03-04 00:44:10','2026-03-04 00:44:10'),(18,1,'api.order.mark_delivered','App\\Models\\Order',6,'{\"order_code\":\"S59-GWNYIX0U\"}','127.0.0.1','2026-03-04 00:44:10','2026-03-04 00:44:10'),(19,1,'api.order.mark_paid','App\\Models\\Order',4,'{\"order_code\":\"S59-8CRFUVFN\"}','127.0.0.1','2026-03-04 00:44:13','2026-03-04 00:44:13'),(20,1,'api.order.mark_paid','App\\Models\\Order',1,'{\"order_code\":\"S59-A7ONZOIM\"}','127.0.0.1','2026-03-04 00:44:15','2026-03-04 00:44:15'),(21,1,'api.order.mark_delivered','App\\Models\\Order',4,'{\"order_code\":\"S59-8CRFUVFN\"}','127.0.0.1','2026-03-04 00:44:15','2026-03-04 00:44:15'),(22,1,'api.order.mark_delivered','App\\Models\\Order',1,'{\"order_code\":\"S59-A7ONZOIM\"}','127.0.0.1','2026-03-04 00:44:17','2026-03-04 00:44:17'),(23,1,'order.mark_paid','App\\Models\\Order',7,'{\"order_code\":\"S59-NL33SDDK\"}','127.0.0.1','2026-03-04 14:50:08','2026-03-04 14:50:08');
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cache`
--

DROP TABLE IF EXISTS `cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cache` (
  `key` varchar(255) NOT NULL,
  `value` mediumtext NOT NULL,
  `expiration` int(11) NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache`
--

LOCK TABLES `cache` WRITE;
/*!40000 ALTER TABLE `cache` DISABLE KEYS */;
INSERT INTO `cache` VALUES ('laravel-cache-f46dfee1a5eeb2fd9bdd2dfad4f7345e','i:1;',1772637617),('laravel-cache-f46dfee1a5eeb2fd9bdd2dfad4f7345e:timer','i:1772637617;',1772637617);
/*!40000 ALTER TABLE `cache` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cache_locks`
--

DROP TABLE IF EXISTS `cache_locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cache_locks` (
  `key` varchar(255) NOT NULL,
  `owner` varchar(255) NOT NULL,
  `expiration` int(11) NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_locks_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache_locks`
--

LOCK TABLES `cache_locks` WRITE;
/*!40000 ALTER TABLE `cache_locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache_locks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_password_histories`
--

DROP TABLE IF EXISTS `event_password_histories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_password_histories` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `changed_by` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_password_histories_event_id_foreign` (`event_id`),
  KEY `event_password_histories_changed_by_foreign` (`changed_by`),
  CONSTRAINT `event_password_histories_changed_by_foreign` FOREIGN KEY (`changed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `event_password_histories_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_password_histories`
--

LOCK TABLES `event_password_histories` WRITE;
/*!40000 ALTER TABLE `event_password_histories` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_password_histories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `event_sessions`
--

DROP TABLE IF EXISTS `event_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_sessions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `token_hash` varchar(64) NOT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `event_sessions_token_hash_unique` (`token_hash`),
  KEY `event_sessions_event_id_expires_at_index` (`event_id`,`expires_at`),
  CONSTRAINT `event_sessions_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `event_sessions`
--

LOCK TABLES `event_sessions` WRITE;
/*!40000 ALTER TABLE `event_sessions` DISABLE KEYS */;
INSERT INTO `event_sessions` VALUES (1,1,'cacf6496a3471d21f8ac0d28dbc266ab22bda30cc9c2f38a0ba6aa2888ffe116','2026-03-05 00:16:42','2026-03-04 00:16:42','2026-03-04 00:16:42'),(2,1,'6d4dbc09d2015de2e5edfefc023956b775b82e15256762b0e2b5b722a71de4cf','2026-03-05 00:26:59','2026-03-04 00:26:59','2026-03-04 00:26:59'),(3,1,'4f4c6ebc1bc70be24f01fc39ad6a14e045157a5938a926f912a47fd488ec6af9','2026-03-05 00:29:36','2026-03-04 00:29:36','2026-03-04 00:29:36'),(4,1,'0d64b79c72695e26b020153614f770d0134ce458d1db7cd50956569f2d564c25','2026-03-05 00:31:10','2026-03-04 00:31:10','2026-03-04 00:31:10'),(5,1,'66d5f07691c89fdf2af633c3d4581a7edb586d302165330fa5f1e2a6327bf3da','2026-03-05 00:31:50','2026-03-04 00:31:50','2026-03-04 00:31:50'),(6,1,'881ba250f10493149c388d7bb581a197f83f580408f42976c84fbb11f1a48efb','2026-03-05 00:36:14','2026-03-04 00:36:14','2026-03-04 00:36:14'),(7,1,'995cfc53aaedeb811f1a83e71e4473143e82de9d758b7ac895517889b8b7fe11','2026-03-05 00:42:17','2026-03-04 00:42:17','2026-03-04 00:42:17'),(8,1,'acc0eab24f8d73957a74c404087596d2582d5251bc958088374c53ece000b456','2026-03-05 00:45:00','2026-03-04 00:45:00','2026-03-04 00:45:00'),(9,1,'cf47eb8f3ed9ff535ce010354d4c3e9c53f197e15acea0dbb24624ad26491bc4','2026-03-05 00:47:27','2026-03-04 00:47:27','2026-03-04 00:47:27'),(10,1,'3f07509814d65310942988972f39525cf71007b5715d1ca53426a006c4eabf03','2026-03-05 00:49:52','2026-03-04 00:49:52','2026-03-04 00:49:52'),(11,1,'48185cca5c869bbc4980398b5f23a5c67d200e6646bf5b8525ee698d4e5d6441','2026-03-05 14:48:47','2026-03-04 14:48:47','2026-03-04 14:48:47'),(12,1,'288adfc5e8f5b654755ae46b892587051d813e2022d23f8725bf490db8204571','2026-03-05 14:49:28','2026-03-04 14:49:28','2026-03-04 14:49:28');
/*!40000 ALTER TABLE `event_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `events`
--

DROP TABLE IF EXISTS `events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `event_date` date NOT NULL,
  `location` varchar(255) DEFAULT NULL,
  `access_password` varchar(255) NOT NULL,
  `is_active_today` tinyint(1) NOT NULL DEFAULT 0,
  `price_per_photo` decimal(10,2) NOT NULL DEFAULT 2.50,
  `created_by` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `events_created_by_foreign` (`created_by`),
  KEY `events_event_date_is_active_today_index` (`event_date`,`is_active_today`),
  CONSTRAINT `events_created_by_foreign` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `events`
--

LOCK TABLES `events` WRITE;
/*!40000 ALTER TABLE `events` DISABLE KEYS */;
INSERT INTO `events` VALUES (1,'Demo','2026-03-04','Lisboa','1234',1,2.50,1,'2026-03-03 22:47:11','2026-03-04 00:14:46');
/*!40000 ALTER TABLE `events` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `failed_jobs`
--

DROP TABLE IF EXISTS `failed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `failed_jobs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) NOT NULL,
  `connection` text NOT NULL,
  `queue` text NOT NULL,
  `payload` longtext NOT NULL,
  `exception` longtext NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `failed_jobs`
--

LOCK TABLES `failed_jobs` WRITE;
/*!40000 ALTER TABLE `failed_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `failed_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_batches`
--

DROP TABLE IF EXISTS `job_batches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `job_batches` (
  `id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `total_jobs` int(11) NOT NULL,
  `pending_jobs` int(11) NOT NULL,
  `failed_jobs` int(11) NOT NULL,
  `failed_job_ids` longtext NOT NULL,
  `options` mediumtext DEFAULT NULL,
  `cancelled_at` int(11) DEFAULT NULL,
  `created_at` int(11) NOT NULL,
  `finished_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `job_batches`
--

LOCK TABLES `job_batches` WRITE;
/*!40000 ALTER TABLE `job_batches` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_batches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `jobs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) NOT NULL,
  `payload` longtext NOT NULL,
  `attempts` tinyint(3) unsigned NOT NULL,
  `reserved_at` int(10) unsigned DEFAULT NULL,
  `available_at` int(10) unsigned NOT NULL,
  `created_at` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `jobs`
--

LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `migrations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES (1,'0001_01_01_000000_create_users_table',1),(2,'0001_01_01_000001_create_cache_table',1),(3,'0001_01_01_000002_create_jobs_table',1),(4,'2026_03_03_205628_create_personal_access_tokens_table',1),(5,'2026_03_03_205643_create_event_sessions_table',1),(6,'2026_03_03_205643_create_events_table',1),(7,'2026_03_03_205643_create_order_items_table',1),(8,'2026_03_03_205643_create_orders_table',1),(9,'2026_03_03_205643_create_photos_table',1),(10,'2026_03_03_205643_create_upload_chunks_table',1),(11,'2026_03_03_221822_add_photo_id_to_upload_chunks_table',1),(12,'2026_03_03_224652_add_missing_foreign_keys_for_mysql_ordering',1),(13,'2026_03_03_231018_add_preview_fields_to_photos_table',2),(14,'2026_03_03_231018_add_role_to_users_table',2),(15,'2026_03_03_231018_create_audit_logs_table',2),(16,'2026_03_03_231018_create_event_password_histories_table',2),(17,'2026_03_03_235100_add_download_access_to_orders_table',3);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_items`
--

DROP TABLE IF EXISTS `order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `order_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `order_id` bigint(20) unsigned NOT NULL,
  `photo_id` bigint(20) unsigned NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_items_order_id_photo_id_unique` (`order_id`,`photo_id`),
  KEY `order_items_order_id_index` (`order_id`),
  KEY `order_items_photo_id_index` (`photo_id`),
  CONSTRAINT `order_items_order_id_foreign` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `order_items_photo_id_foreign` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=47 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_items`
--

LOCK TABLES `order_items` WRITE;
/*!40000 ALTER TABLE `order_items` DISABLE KEYS */;
INSERT INTO `order_items` VALUES (1,1,27,2.50,'2026-03-03 23:23:34','2026-03-03 23:23:34'),(2,1,28,2.50,'2026-03-03 23:23:34','2026-03-03 23:23:34'),(3,1,32,2.50,'2026-03-03 23:23:34','2026-03-03 23:23:34'),(4,1,35,2.50,'2026-03-03 23:23:34','2026-03-03 23:23:34'),(5,2,28,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(6,2,29,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(7,2,30,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(8,2,31,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(9,2,34,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(10,2,35,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(11,2,36,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(12,2,37,2.50,'2026-03-03 23:29:36','2026-03-03 23:29:36'),(13,3,27,2.50,'2026-03-03 23:39:40','2026-03-03 23:39:40'),(14,3,28,2.50,'2026-03-03 23:39:40','2026-03-03 23:39:40'),(15,3,31,2.50,'2026-03-03 23:39:40','2026-03-03 23:39:40'),(16,3,32,2.50,'2026-03-03 23:39:40','2026-03-03 23:39:40'),(17,3,35,2.50,'2026-03-03 23:39:40','2026-03-03 23:39:40'),(18,3,36,2.50,'2026-03-03 23:39:40','2026-03-03 23:39:40'),(19,4,28,2.50,'2026-03-04 00:32:26','2026-03-04 00:32:26'),(20,4,31,2.50,'2026-03-04 00:32:26','2026-03-04 00:32:26'),(21,4,32,2.50,'2026-03-04 00:32:26','2026-03-04 00:32:26'),(22,5,26,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(23,5,27,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(24,5,28,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(25,5,29,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(26,5,30,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(27,5,31,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(28,5,32,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(29,5,33,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(30,5,34,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(31,5,35,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(32,5,36,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(33,5,37,2.50,'2026-03-04 00:36:49','2026-03-04 00:36:49'),(34,6,28,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(35,6,29,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(36,6,30,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(37,6,31,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(38,6,32,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(39,6,33,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(40,6,34,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(41,6,35,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(42,6,36,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(43,6,37,2.50,'2026-03-04 00:42:45','2026-03-04 00:42:45'),(44,7,27,2.50,'2026-03-04 14:49:56','2026-03-04 14:49:56'),(45,7,29,2.50,'2026-03-04 14:49:56','2026-03-04 14:49:56'),(46,7,32,2.50,'2026-03-04 14:49:56','2026-03-04 14:49:56');
/*!40000 ALTER TABLE `order_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `orders` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `order_code` varchar(255) NOT NULL,
  `customer_name` varchar(255) NOT NULL,
  `customer_phone` varchar(255) DEFAULT NULL,
  `customer_email` varchar(255) DEFAULT NULL,
  `payment_method` enum('online','cash') NOT NULL,
  `status` enum('pending','paid','delivered') NOT NULL DEFAULT 'pending',
  `total_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `download_token_hash` varchar(64) DEFAULT NULL,
  `download_link_sent_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `orders_order_code_unique` (`order_code`),
  KEY `orders_event_id_status_index` (`event_id`,`status`),
  KEY `orders_download_token_hash_index` (`download_token_hash`),
  CONSTRAINT `orders_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders`
--

LOCK TABLES `orders` WRITE;
/*!40000 ALTER TABLE `orders` DISABLE KEYS */;
INSERT INTO `orders` VALUES (1,1,'S59-A7ONZOIM','Carlos Alberto Silva da Cunha',NULL,NULL,'cash','delivered',10.00,NULL,NULL,'2026-03-03 23:23:34','2026-03-04 00:44:17'),(2,1,'S59-QQSK0TH0','julia',NULL,NULL,'cash','delivered',20.00,NULL,NULL,'2026-03-03 23:29:36','2026-03-03 23:30:06'),(3,1,'S59-YVPDTWQE','MIGUEL BARRETO CORREIA DE ARAÚJO',NULL,'socialonline23@gmail.com','cash','delivered',15.00,'bece668ae013ed42d253d1203a8fa0606c7afd2b7193ee068826e87c26ec6946','2026-03-03 23:49:08','2026-03-03 23:39:40','2026-03-04 00:44:09'),(4,1,'S59-8CRFUVFN','Miguel',NULL,'socialonline23@gmail.com','cash','delivered',7.50,'54d5c9f2d4cf086dc06505751451867068c0af01d00ff3c2cfa6e4d16b253eaf','2026-03-04 00:44:13','2026-03-04 00:32:26','2026-03-04 00:44:15'),(5,1,'S59-6GLZSGU0','Ze Augusto',NULL,'socialonline23@gmail.com','cash','delivered',30.00,'c24fb455cd3efd6562c5e679a0f3605e95b7db5fb962f58647edf68176277c8a','2026-03-04 00:37:36','2026-03-04 00:36:49','2026-03-04 00:44:10'),(6,1,'S59-GWNYIX0U','Miguel Albertino',NULL,'socialonline23@gmail.com','cash','delivered',25.00,'7d6031facbd2e1371ee00eea9b434a43c35fe1de99d46b708941a5889e3cd3be','2026-03-04 00:42:52','2026-03-04 00:42:45','2026-03-04 00:44:10'),(7,1,'S59-NL33SDDK','Nome do Cliente',NULL,'socialonline23@gmail.com','cash','paid',7.50,'9d83cee66f1b7b3b500e5b53fe571a7c48ad7a43a6495e7510eb24a9257b0ecb','2026-03-04 14:50:08','2026-03-04 14:49:56','2026-03-04 14:50:08');
/*!40000 ALTER TABLE `orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_reset_tokens`
--

DROP TABLE IF EXISTS `password_reset_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `password_reset_tokens` (
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_reset_tokens`
--

LOCK TABLES `password_reset_tokens` WRITE;
/*!40000 ALTER TABLE `password_reset_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_reset_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `personal_access_tokens`
--

DROP TABLE IF EXISTS `personal_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL,
  `tokenable_id` bigint(20) unsigned NOT NULL,
  `name` text NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`),
  KEY `personal_access_tokens_expires_at_index` (`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `personal_access_tokens`
--

LOCK TABLES `personal_access_tokens` WRITE;
/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
INSERT INTO `personal_access_tokens` VALUES (1,'App\\Models\\User',1,'staff-mobile','98f7281da5bfc187eeb54d4ad920194be5d216b34dad42ff32273ae554f328be','[\"*\"]',NULL,NULL,'2026-03-04 00:10:00','2026-03-04 00:10:00'),(2,'App\\Models\\User',1,'staff-mobile','ae0adc4e000560f43b757890b2cc3595dd98b3a237ed113632f2a128aab5ae68','[\"*\"]',NULL,NULL,'2026-03-04 00:10:23','2026-03-04 00:10:23'),(3,'App\\Models\\User',1,'staff-mobile','6cf20b24fa048319ae8acc5254b3bdb51feb6cf47394e110a8c1278574c2b667','[\"*\"]','2026-03-04 00:44:17',NULL,'2026-03-04 00:43:48','2026-03-04 00:44:17');
/*!40000 ALTER TABLE `personal_access_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `photos`
--

DROP TABLE IF EXISTS `photos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `photos` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `number` varchar(10) NOT NULL,
  `original_path` varchar(255) NOT NULL,
  `preview_path` varchar(255) DEFAULT NULL,
  `preview_status` varchar(20) NOT NULL DEFAULT 'pending',
  `preview_error` text DEFAULT NULL,
  `mime` varchar(100) DEFAULT NULL,
  `size` bigint(20) unsigned NOT NULL DEFAULT 0,
  `width` int(10) unsigned DEFAULT NULL,
  `height` int(10) unsigned DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `checksum` varchar(64) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `photos_event_id_number_unique` (`event_id`,`number`),
  UNIQUE KEY `photos_event_id_checksum_unique` (`event_id`,`checksum`),
  KEY `photos_event_id_preview_status_index` (`event_id`,`preview_status`),
  CONSTRAINT `photos_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `photos`
--

LOCK TABLES `photos` WRITE;
/*!40000 ALTER TABLE `photos` DISABLE KEYS */;
INSERT INTO `photos` VALUES (26,1,'0001','events/1/originals/0001.jpg','events/1/previews/0001.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:01','2026-03-04 00:28:28'),(27,1,'0002','events/1/originals/0002.jpg','events/1/previews/0002.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:01','2026-03-04 00:28:28'),(28,1,'0003','events/1/originals/0003.jpg','events/1/previews/0003.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:02','2026-03-04 00:28:28'),(29,1,'0004','events/1/originals/0004.jpg','events/1/previews/0004.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:02','2026-03-04 00:28:28'),(30,1,'0005','events/1/originals/0005.jpg','events/1/previews/0005.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:03','2026-03-04 00:28:28'),(31,1,'0006','events/1/originals/0006.jpg','events/1/previews/0006.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:03','2026-03-04 00:28:28'),(32,1,'0007','events/1/originals/0007.jpg','events/1/previews/0007.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:03','2026-03-04 00:28:28'),(33,1,'0008','events/1/originals/0008.jpg','events/1/previews/0008.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:04','2026-03-04 00:28:28'),(34,1,'0009','events/1/originals/0009.jpg','events/1/previews/0009.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:04','2026-03-04 00:28:28'),(35,1,'0010','events/1/originals/0010.jpg','events/1/previews/0010.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:05','2026-03-04 00:28:28'),(36,1,'0011','events/1/originals/0011.jpg','events/1/previews/0011.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:05','2026-03-04 00:28:28'),(37,1,'0012','events/1/originals/0012.jpg','events/1/previews/0012.jpg','ready',NULL,'image/jpeg',75894,1248,832,'active',NULL,'2026-03-03 22:57:06','2026-03-04 00:28:28');
/*!40000 ALTER TABLE `photos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sessions` (
  `id` varchar(255) NOT NULL,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `payload` longtext NOT NULL,
  `last_activity` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sessions_user_id_index` (`user_id`),
  KEY `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
INSERT INTO `sessions` VALUES ('4sySmqnBJmynORtZMY7R7jUMtCVFrjOYhRh2tztp',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiZldNU0JJdDZXcDhaVjdBYzBWWEpPekJ6VTBoemlGa1lYRXFCNktjaSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjciO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635729),('5386y0nnyiGrCYU9egLmuMdre6WddUrJUKxmSEZG',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiYmljQ0VoZlYzYTFUUWJESjNXVFpDcmx5bWIxS0JGbUN1S3hXZUZ0dSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzAiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635730),('7cKfXqf3dt6BID3bJwt9kijcK3PAMqZZWjFANl1J',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiNUwxaHBmTnAxdTZmV1Z1WGk5WlliaWEyOGJRWW9CVlJIWGlpOWRjSSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzciO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635773),('aOoNDnQc0WFfWY9qLPWWhW9x1F96UH7Qms4eAAGZ',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoidDRySmxFa3Z5dnF2SWN1MUNuMVNLVnU1bHdualZWTU9WTTFuZ0hEZiI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzUiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635772),('AOy8HEHCfV4aJxBe8MordfLYjCZTRSPrhRqKF3YX',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiRmQzd2tVVjlWM0RoUFoxeHN2YzZPeDlUdlBKM3lCRFRjQ2I5enR3MiI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjgiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635729),('DMEcRnc9lYxYunr98p7I97HeRjGChcNYUh5F0rzP',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiY1VYeXBNZ2ZFVkM1bTU3TFhMUUxxSkhlWDRKMW1xRVMxY3NraFB2dCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzciO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635732),('EKDDKkvM3Tp2cD2cLH2MGnC0Xbhf9YYXL6tQagNW',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiUkJ5SnlqM2oxaUtWYWdHeE1tVHBkM0ZYWEppQWltQzRVbmpsS2swVyI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzEiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635730),('ENvXuH6vjWR1fLgnqv0nF0Ph757H3kUjlAotfgQ5',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoidWEyREhFc1FwUVRDR3hoY3NzN3RuUFJHOEpJQUduRWozcHJCV1lCSyI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzAiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635771),('FXbwKDlB0vnTvSdZ6YfUguEYa7oqChNjzgknQNlC',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoidGJQcnFVZ0F1WTRrd25jUEQ2N2ZVZHZuZ2RXOFhmMFZ5T2k3amNtYSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzQiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635778),('GydVRV0Qz6NO7rMRWKIspWcheCjC4CJla1Yqexz8',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiUXJrcElBOXl1aWlHeUd2eHFHcklZRlBBSHRKczBqRkJNYldZM0N3TCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjgiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635770),('IN8Wm1qmZgdQyuHZRVE4ETloWVnp11Zvo4UIIZas',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiRWJabWNoQzRwMkVySE85WjJrRk50UTAybm1JdTlkcXlCY1NOWk9adyI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzYiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635773),('JfZwFXZzxDtkJ8vUq0et5RgEh3FSVTIuddaWUJXM',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiMWR6V29xM0lkak9LWUJkcHRhMkdLaHZUd2VLWVBBUGxZR1pnME9ZRCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjYiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635728),('K9Eddsdvk5Otvilj88tXiwdceCqIYrJVVH8obEcl',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiTVhtNHRlRmxsUkt5UGZvTHJic2ZaczJQMjZndnc5dU5QWG5mbERRNCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzIiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635730),('KGJDrWAu3o0PNgmtUXox19x8nBIhp17P3nJiwtiq',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoicVRxUVo2MXBtSHJ5cTI0b3plemFPTlEzNU9DN2U5V2RoMHZEa25laSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzQiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635772),('lQuqvsbLKiZjOYdCEcVkTOidvQN547P2hilCPm5y',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiN0xXMXlwMU9JanhSUGZ2MTVtak9rdmYxMzRKZmR6cHZRUGZZM3NVMiI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzYiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635778),('LuNjLRJ7ZKwVCuhYtJeq0ouzLzUtRXLmZyMQwUnh',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoieHBOdXRPVmloWWdKVjU4SDdqZ1NBU1BoVGxiUjM1SHF4eUhlcloxVyI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzIiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635771),('miKEE8HoHkFCg80UAvImY7dNFTfTlPNISV2ROfGy',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoibG9aYVBCTjY1RmtqMmZCa1NmSzhoSWs0S1NYbkRrQzNCOERwdUJqbyI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzEiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635779),('noC0TclipG2Yt1De3Ua8DuYWCYIXKZnT2wH329qO',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiY3hCMDlNU2k2S0xZZThxYkRHdG9FU3VOZkhaODIwVFZieEhNbEk2USI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzMiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635777),('nZT09qwdCkwIs0QDmjKhSuIzqBU49wzunJ5pdTuI',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiUnkybVBqVU5UODA4cWMwMGJsb2hlVEJkMnAxM1NXdkExeGRqWUJQOSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzUiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635779),('NZtkEMaFA6O8Ff7CrBTWmN942gaTfW7X43lhywX6',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiNE1wZUJVRWpIcFdMOUVSU1hCU1lpbExEQk1pR2VsVmlBVDdvQ242MCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzYiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635731),('ocnmO9IP1zNBZFhNYKjEEIO8c1Flv31jZn19gnD7',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiMnBjVnJFb01Rb1NaZ3FQbTBCUVNUbXM3MGZmVWlpN1dBbk9kSnlWaCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjciO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635770),('OZN9rghPkZuNGrhXc3ehGBCbUiyw1DEZcuvrNNVE',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiemJnSG15bm5lemNSSXN3MmdTcGNPQmlZTkIxanB1dVdKSVkwUDZocSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzAiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635777),('PR0OlqLZzWEVHkezMCAJ46RMCBszWi9LGdtvtkUy',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoieFpZZVNrOFRVNFRwOGQ2SGVuelQ1RTVQVzVUemRYZ1NLNE41a0x2cCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjYiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635770),('t7h4IZnQsSktiX0SEuutVTQUHeN1gMlY2ncnRlUF',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiZTU1YnNxM3lwcXlOSWpsOUloZmlBa2dwUmhIZ1lrMnZRWEZyTVU0NCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzUiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635731),('v3g1NOuR60CuRR4ybkAhMFrpK3MEC6eLJQu54DNk',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiZEhqY256RjZSMjFPRHlCTzh6NEpkWXZmTzlZOERXQWtUSHRXWXVEeSI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzQiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635731),('Vc04SkeDMbVMeDQtXblAjKWazEnpIwVLKTX0bvJf',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiRXhEcGo2VURuUEs0NUdqdUROalhqVjdpZ2FMajdMUnhSdUZ5MVZzYyI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzMiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635772),('VCMg72Eysyp8nPXtUFGCkJBRdSw3xPHpFdkHrDco',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiMEhTaGFUemN1akd5Zm80M1FobDUyZTB0a0JyekN6VEhqMGtwMmV4RCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjkiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635770),('WYuF5nsTZBNbVujsp8nf9jlUTlpQo4tOpp3avv6u',1,'127.0.0.1','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36','YTo0OntzOjY6Il90b2tlbiI7czo0MDoiS1ZqNVFQQzFqZHk0aWw4eU5JYWc5OFJTU2VlWlpkTTdpOG9qejl5UCI7czo1MDoibG9naW5fd2ViXzU5YmEzNmFkZGMyYjJmOTQwMTU4MGYwMTRjN2Y1OGVhNGUzMDk4OWQiO2k6MTtzOjk6Il9wcmV2aW91cyI7YToyOntzOjM6InVybCI7czoyMToiaHR0cDovLzEyNy4wLjAuMTo4MDAwIjtzOjU6InJvdXRlIjtzOjk6ImRhc2hib2FyZCI7fXM6NjoiX2ZsYXNoIjthOjI6e3M6Mzoib2xkIjthOjA6e31zOjM6Im5ldyI7YTowOnt9fX0=',1772637203),('xFM2DSyIlOPBSFkkOM2ShtAJw1ISqIBvDBZzYBvb',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiWDhBY3pmWE9iVkxmZkhaMnYyVGxyNUtoMm9kZ0p4QjFwVThMU1A4ZCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzciO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635778),('XhpGMig3ryz7OHchyOrfaLtKG11wtVnYjHr9fQQ2',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoib0dWZEZXUXBmMm44Z09UUGp4SUpIY3N5R09CcXpzT2lGVnl6VGNyViI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzMiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635730),('xu0lIZ0qXHAEilAgrdf9ejjefkFZUSPCgTPIFzWl',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiMWFBWkN6RWxVU0twTWpyZEszSlpBSTYxODlTd25Edk5ZY2M0VkVPRCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMzEiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635771),('ZQvk0XpU4D26w3oiCW7qey3fFQUMLupPXdI2RfLa',NULL,'127.0.0.1','Dart/3.11 (dart:io)','YTozOntzOjY6Il90b2tlbiI7czo0MDoiMjBDNGczYjVNbjFNY3BVUFAyMkYxWFNRVjdTaFI4UjBsemJVV2RUeCI7czo5OiJfcHJldmlvdXMiO2E6Mjp7czozOiJ1cmwiO3M6MzE6Imh0dHA6Ly8xMC4wLjIuMjo4MDAwL3ByZXZpZXcvMjkiO3M6NToicm91dGUiO3M6MTM6InByZXZpZXcuaW1hZ2UiO31zOjY6Il9mbGFzaCI7YToyOntzOjM6Im9sZCI7YTowOnt9czozOiJuZXciO2E6MDp7fX19',1772635729);
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `upload_chunks`
--

DROP TABLE IF EXISTS `upload_chunks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `upload_chunks` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `upload_id` varchar(100) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `total_chunks` int(10) unsigned NOT NULL,
  `received_chunks` int(10) unsigned NOT NULL DEFAULT 0,
  `is_completed` tinyint(1) NOT NULL DEFAULT 0,
  `photo_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `upload_chunks_event_id_upload_id_unique` (`event_id`,`upload_id`),
  KEY `upload_chunks_photo_id_foreign` (`photo_id`),
  CONSTRAINT `upload_chunks_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `upload_chunks_photo_id_foreign` FOREIGN KEY (`photo_id`) REFERENCES `photos` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `upload_chunks`
--

LOCK TABLES `upload_chunks` WRITE;
/*!40000 ALTER TABLE `upload_chunks` DISABLE KEYS */;
INSERT INTO `upload_chunks` VALUES (1,1,'1772578144968-25229uifk9-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (2).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__2_.jpeg',1,1,1,NULL,'2026-03-03 22:49:13','2026-03-03 22:49:13'),(2,1,'1772578144970-f7hh1h5ld7-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (3).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__3_.jpeg',1,1,1,NULL,'2026-03-03 22:49:15','2026-03-03 22:49:15'),(3,1,'1772578144973-hkhw36q9qx-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (4).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__4_.jpeg',1,1,1,NULL,'2026-03-03 22:49:17','2026-03-03 22:49:17'),(4,1,'1772578144975-k5n0shveim-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (5).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__5_.jpeg',1,1,1,NULL,'2026-03-03 22:49:19','2026-03-03 22:49:19'),(5,1,'1772578144978-szulsxnanx-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (6).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__6_.jpeg',1,1,1,NULL,'2026-03-03 22:49:21','2026-03-03 22:49:21'),(6,1,'1772578144982-w27kcjlzcs-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (7).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__7_.jpeg',1,1,1,NULL,'2026-03-03 22:49:23','2026-03-03 22:49:23'),(7,1,'1772578144986-j22bxp3z65-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (8).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__8_.jpeg',1,1,1,NULL,'2026-03-03 22:49:25','2026-03-03 22:49:25'),(8,1,'1772578144989-f5wlyjk7y5-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (9).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__9_.jpeg',1,1,1,NULL,'2026-03-03 22:49:27','2026-03-03 22:49:27'),(9,1,'1772578144994-tq2c8p6i5o-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (10).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__10_.jpeg',1,1,1,NULL,'2026-03-03 22:49:29','2026-03-03 22:49:29'),(10,1,'1772578144998-n1du2cpjzl-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (11).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__11_.jpeg',1,1,1,NULL,'2026-03-03 22:49:31','2026-03-03 22:49:31'),(11,1,'1772578145003-b67tb82rqi-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (12).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__12_.jpeg',1,1,1,NULL,'2026-03-03 22:49:33','2026-03-03 22:49:33'),(12,1,'1772578145008-ll39vz41ki-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (13).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__13_.jpeg',1,1,1,NULL,'2026-03-03 22:49:35','2026-03-03 22:49:35'),(13,1,'1772578145014-jcbnyogqyk-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (14).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__14_.jpeg',1,1,1,NULL,'2026-03-03 22:49:37','2026-03-03 22:49:37'),(14,1,'1772578145019-2wpcxwzno3-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (15).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__15_.jpeg',1,1,1,NULL,'2026-03-03 22:49:39','2026-03-03 22:49:39'),(15,1,'1772578145026-3nzj22am85-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (16).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__16_.jpeg',1,1,1,NULL,'2026-03-03 22:49:41','2026-03-03 22:49:41'),(16,1,'1772578145032-2wosyhbs1k-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (17).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__17_.jpeg',1,1,1,NULL,'2026-03-03 22:49:43','2026-03-03 22:49:43'),(17,1,'1772578145039-v5xahf32eg-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (18).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__18_.jpeg',1,1,1,NULL,'2026-03-03 22:49:45','2026-03-03 22:49:45'),(18,1,'1772578145046-86m1d7xjf0-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (19).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__19_.jpeg',1,1,1,NULL,'2026-03-03 22:49:47','2026-03-03 22:49:47'),(19,1,'1772578145053-z086se3mti-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (20).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__20_.jpeg',1,1,1,NULL,'2026-03-03 22:49:49','2026-03-03 22:49:49'),(20,1,'1772578145059-ear3u4w0e6-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (21).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__21_.jpeg',1,1,1,NULL,'2026-03-03 22:49:50','2026-03-03 22:49:51'),(21,1,'1772578145066-dful9c9x6o-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (22).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__22_.jpeg',1,1,1,NULL,'2026-03-03 22:49:52','2026-03-03 22:49:52'),(22,1,'1772578145073-rrr31feqju-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (23).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__23_.jpeg',1,1,1,NULL,'2026-03-03 22:49:54','2026-03-03 22:49:54'),(23,1,'1772578145079-g772blc77j-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia (24).jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia__24_.jpeg',1,1,1,NULL,'2026-03-03 22:49:55','2026-03-03 22:49:55'),(24,1,'1772578145731-0u0gzwxvwq-75894-WhatsApp Image 2026-01-20 at 11.57.59 - Cópia.jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia.jpeg',1,1,1,NULL,'2026-03-03 22:51:18','2026-03-03 22:51:19'),(25,1,'1772578145736-uktodzhgkf-75894-WhatsApp Image 2026-01-20 at 11.57.59.jpeg-1769971399875','WhatsApp_Image_2026-01-20_at_11.57.59.jpeg',1,1,1,NULL,'2026-03-03 22:51:19','2026-03-03 22:51:19'),(26,1,'ummb7jlei-1-9ljvjf','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia_-_C__pia_-_C__pia.jpeg',1,1,1,26,'2026-03-03 22:57:01','2026-03-03 22:57:01'),(27,1,'ummb7jlek-2-7tnqb6','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia_-_C__pia__2_.jpeg',1,1,1,27,'2026-03-03 22:57:01','2026-03-03 22:57:01'),(28,1,'ummb7jlek-3-czalc5','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia_-_C__pia.jpeg',1,1,1,28,'2026-03-03 22:57:02','2026-03-03 22:57:02'),(29,1,'ummb7jlel-4-mke4r0','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia__2__-_C__pia.jpeg',1,1,1,29,'2026-03-03 22:57:02','2026-03-03 22:57:02'),(30,1,'ummb7jlel-5-jmn3rf','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia__2_.jpeg',1,1,1,30,'2026-03-03 22:57:02','2026-03-03 22:57:03'),(31,1,'ummb7jlel-6-72b3ns','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia__3_.jpeg',1,1,1,31,'2026-03-03 22:57:03','2026-03-03 22:57:03'),(32,1,'ummb7jlem-7-aj4vkc','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia_-_C__pia.jpeg',1,1,1,32,'2026-03-03 22:57:03','2026-03-03 22:57:04'),(33,1,'ummb7jlem-8-v9vqzd','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia__2__-_C__pia_-_C__pia.jpeg',1,1,1,33,'2026-03-03 22:57:04','2026-03-03 22:57:04'),(34,1,'ummb7jlen-9-mchbo0','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia__2__-_C__pia.jpeg',1,1,1,34,'2026-03-03 22:57:04','2026-03-03 22:57:04'),(35,1,'ummb7jleo-a-3l8izo','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia__2_.jpeg',1,1,1,35,'2026-03-03 22:57:05','2026-03-03 22:57:05'),(36,1,'ummb7jleo-b-c5gf0x','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia__3__-_C__pia.jpeg',1,1,1,36,'2026-03-03 22:57:05','2026-03-03 22:57:05'),(37,1,'ummb7jlep-c-a28lmt','WhatsApp_Image_2026-01-20_at_11.57.59_-_C__pia_-_C__pia__3_.jpeg',1,1,1,37,'2026-03-03 22:57:06','2026-03-03 22:57:06');
/*!40000 ALTER TABLE `upload_chunks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `role` varchar(20) NOT NULL DEFAULT 'staff',
  `remember_token` varchar(100) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Studio 59 Admin','admin@studio59.local',NULL,'$2y$12$DuCS9oBriUB9Otqt6M/steqfeb1OJD7RMtPaK7OTmVUvA/Vdohm0i','admin','e7NBQIEmXyKXWq5HdC1Pk51BomSqHmnO455ZLp46bJZVMqPWQYzBCRl0hdGi','2026-03-03 22:47:11','2026-03-03 23:21:03'),(2,'Studio 59 Staff','staff@studio59.local',NULL,'$2y$12$fKcih5f4iYGU4hZWuMQBJu6CztLiQT8P.e1pgVMzokQHs9pTOX0du','staff',NULL,'2026-03-03 23:21:03','2026-03-03 23:21:03');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping routines for database 'studio59'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-03-04 15:19:48
