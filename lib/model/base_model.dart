abstract class BaseModel {
  int? id;
  DateTime? createdAt;
  DateTime? updatedAt;

  BaseModel({this.id, this.createdAt, this.updatedAt});

  Map<String, dynamic> toJson();
}
