// lib/models/farmer.dart

class HashSummary {
  final int hashId;
  final String title;
  final int difficulty;

  HashSummary({
    required this.hashId,
    required this.title,
    required this.difficulty,
  });

  factory HashSummary.fromJson(Map<String, dynamic> json) {
    return HashSummary(
      hashId: json['hash_id'] as int,
      title: json['title'] as String,
      difficulty: json['difficulty'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'hash_id': hashId,
    'title': title,
    'difficulty': difficulty,
  };
}

class FarmerSummary {
  final int userId;
  final String name;
  final String bio;
  final List<String> tags;
  final String? avatarUrl;
  final List<HashSummary> hashes;

  final bool isFollowing;

  FarmerSummary({
    required this.userId,
    required this.name,
    required this.bio,
    required this.tags,
    required this.avatarUrl,
    required this.hashes,
    required this.isFollowing,
  });

  factory FarmerSummary.fromJson(Map<String, dynamic> json) {
    return FarmerSummary(
      userId: json['user_id'] as int,
      name: json['name'] as String,
      bio: (json['bio'] as String?) ?? '',
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      avatarUrl: json['avatar_url'] as String?,
      hashes: (json['hashes'] as List<dynamic>? ?? [])
          .map((e) => HashSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'bio': bio,
    'tags': tags,
    'avatar_url': avatarUrl,
    'hashes': hashes.map((h) => h.toJson()).toList(),
    'is_following': isFollowing,
  };
}
