import 'dart:convert';

//TODO delete this

class JsonObject {
  dynamic data;

  JsonObject.fromJson(String jsonString) : data = jsonDecode(jsonString);
  JsonObject.fromMap(this.data);
  JsonObject.fromList(this.data);

  String toJson() => jsonEncode(data);
}