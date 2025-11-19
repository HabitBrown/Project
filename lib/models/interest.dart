// lib/models/interest.dart

class Interest {
  final int id;
  final String name;

  Interest({
    required this.id,
    required this.name,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class UserInterestsResponse {
  final int userId;
  final List<Interest> interests;

  UserInterestsResponse({
    required this.userId,
    required this.interests,
  });

  factory UserInterestsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['interests'] as List<dynamic>? ?? [];
    return UserInterestsResponse(
      userId: json['user_id'] as int,
      interests: list
          .map((e) => Interest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
