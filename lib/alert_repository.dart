import 'package:cloud_firestore/cloud_firestore.dart';

class AlertRepository {
  final CollectionReference alerts = FirebaseFirestore.instance.collection(
    'alerts',
  );

  Future<DocumentReference> createAlert(Map<String, dynamic> data) async {
    return alerts.add(data);
  }

  Future<void> updateAlert(String id, Map<String, dynamic> changes) async {
    return alerts.doc(id).update(changes);
  }
}
