import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Medicine Model matching your Firestore structure
class Medicine {
  final String? id;
  final String ndc;
  final String brandName;
  final String genericName;
  final double dosage;
  final String expDate;
  final String status;
  final double purchasePrice;
  final double sellPrice;
  final int supID;
  final String fileType;
  final String sourceFile;
  final String uploadTimestamp;
  final Timestamp uploadedAt;

  Medicine({
    this.id,
    required this.ndc,
    required this.brandName,
    required this.genericName,
    required this.dosage,
    required this.expDate,
    required this.status,
    required this.purchasePrice,
    required this.sellPrice,
    required this.supID,
    this.fileType = 'prescription-scan',
    this.sourceFile = 'camera-scan',
    String? uploadTimestamp,
    Timestamp? uploadedAt,
  }) : this.uploadTimestamp =
           uploadTimestamp ?? DateTime.now().toIso8601String(),
       this.uploadedAt = uploadedAt ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    return {
      'NDC': ndc,
      'brandName': brandName,
      'genericName': genericName,
      'dosage': dosage,
      'expDate': expDate,
      'status': status,
      'purchasePrice': purchasePrice,
      'sellPrice': sellPrice,
      'supID': supID,
      'fileType': fileType,
      'sourceFile': sourceFile,
      'uploadTimestamp': uploadTimestamp,
      'uploadedAt': uploadedAt,
    };
  }

  factory Medicine.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    double parseToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseToInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Medicine(
      id: doc.id,
      ndc: data['NDC']?.toString() ?? '',
      brandName: data['brandName']?.toString() ?? '',
      genericName: data['genericName']?.toString() ?? '',
      dosage: parseToDouble(data['dosage']),
      expDate: data['expDate']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      purchasePrice: parseToDouble(data['purchasePrice']),
      sellPrice: parseToDouble(data['sellPrice']),
      supID: parseToInt(data['supID']),
      fileType: data['fileType']?.toString() ?? 'prescription-scan',
      sourceFile: data['sourceFile']?.toString() ?? 'camera-scan',
      uploadTimestamp: data['uploadTimestamp']?.toString() ?? '',
      uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
    );
  }
}

// Firestore Service
class FirestoreService {
  final CollectionReference medicinesCollection = FirebaseFirestore.instance
      .collection('medicines_stock');

  Future<void> addMedicine(Medicine medicine) async {
    await medicinesCollection.add(medicine.toMap());
  }

  Stream<List<Medicine>> getMedicines() {
    return medicinesCollection
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Medicine.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Medicine>> getMedicinesByStatus(String status) {
    return medicinesCollection
        .where('status', isEqualTo: status)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Medicine.fromFirestore(doc)).toList(),
        );
  }

  Future<void> updateMedicine(String id, Medicine medicine) async {
    await medicinesCollection.doc(id).update(medicine.toMap());
  }

  Future<void> deleteMedicine(String id) async {
    await medicinesCollection.doc(id).delete();
  }
}

// Main Scanner Screen
class PrescriptionScanner extends StatefulWidget {
  @override
  _PrescriptionScannerState createState() => _PrescriptionScannerState();
}

class _PrescriptionScannerState extends State<PrescriptionScanner> {
  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  bool isLoading = false;
  String selectedStatus = 'all';

  Future<void> _pickImage(ImageSource source) async {
    setState(() => isLoading = true);

    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final inputImage = InputImage.fromFilePath(pickedFile.path);
        final textRecognizer = TextRecognizer();
        final RecognizedText recognizedText = await textRecognizer.processImage(
          inputImage,
        );

        List<Medicine> medicines = _extractMedicines(recognizedText.text);

        if (medicines.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No medicines detected'),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          _showConfirmationDialog(medicines);
        }

        textRecognizer.close();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showConfirmationDialog(List<Medicine> medicines) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: BoxConstraints(maxHeight: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFF00BFA5),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Confirm Medicines',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(16),
                      itemCount: medicines.length,
                      itemBuilder: (context, index) {
                        final med = medicines[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.brandName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${med.genericName} • ${med.dosage}mg',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _saveMedicines(medicines);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF00BFA5),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _saveMedicines(List<Medicine> medicines) async {
    setState(() => isLoading = true);
    try {
      for (var medicine in medicines) {
        await _firestoreService.addMedicine(medicine);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medicines.length} medicines saved'),
          backgroundColor: Color(0xFF00BFA5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<Medicine> _extractMedicines(String text) {
    List<Medicine> medicines = [];
    RegExp medicinePattern = RegExp(
      r'([A-Za-z]+(?:\s+[A-Za-z]+)?)\s*[:-]?\s*(\d+)\s*(?:mg|MG|Mg)',
      caseSensitive: false,
    );

    var matches = medicinePattern.allMatches(text);

    for (var match in matches) {
      String name = match.group(1)?.trim() ?? '';
      String dosageStr = match.group(2) ?? '0';
      double dosage = double.tryParse(dosageStr) ?? 0.0;

      if (name.isNotEmpty && dosage > 0) {
        medicines.add(
          Medicine(
            ndc: 'NDC${DateTime.now().millisecondsSinceEpoch}',
            brandName: name,
            genericName: name.toLowerCase(),
            dosage: dosage,
            expDate: _generateExpDate(),
            status: 'active',
            purchasePrice: 0.0,
            sellPrice: 0.0,
            supID: 1,
          ),
        );
      }
    }

    return medicines;
  }

  String _generateExpDate() {
    DateTime expiry = DateTime.now().add(Duration(days: 730));
    return '${expiry.month.toString().padLeft(2, '0')}/${expiry.year.toString().substring(2)}';
  }

  void _editMedicine(Medicine medicine) {
    showDialog(
      context: context,
      builder:
          (context) => EditMedicineDialog(
            medicine: medicine,
            onSave: (updated) async {
              await _firestoreService.updateMedicine(medicine.id!, updated);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Medicine updated'),
                  backgroundColor: Color(0xFF00BFA5),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
    );
  }

  void _deleteMedicine(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 48, color: Colors.red[400]),
                  SizedBox(height: 16),
                  Text(
                    'Delete Medicine',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Remove $name from database?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            padding: EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirm == true) {
      await _firestoreService.deleteMedicine(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medicine deleted'),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medicine Scanner',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Scan prescriptions instantly',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFF00BFA5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<String>(
                          value: selectedStatus,
                          underline: SizedBox(),
                          icon: Icon(
                            Icons.filter_list,
                            size: 18,
                            color: Color(0xFF00BFA5),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00BFA5),
                          ),
                          onChanged: (value) {
                            setState(() => selectedStatus = value!);
                          },
                          items: [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Scan Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildScanButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Camera',
                          onPressed:
                              isLoading
                                  ? null
                                  : () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildScanButton(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          onPressed:
                              isLoading
                                  ? null
                                  : () => _pickImage(ImageSource.gallery),
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Medicine List
            if (isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF00BFA5)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: StreamBuilder<List<Medicine>>(
                  stream:
                      selectedStatus == 'all'
                          ? _firestoreService.getMedicines()
                          : _firestoreService.getMedicinesByStatus(
                            selectedStatus,
                          ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF00BFA5)),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error loading medicines',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.medication_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'No medicines yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Scan a prescription to get started',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    List<Medicine> medicines = snapshot.data!;

                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: medicines.length,
                      itemBuilder: (context, index) {
                        final medicine = medicines[index];
                        return _buildMedicineCard(medicine);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = true,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? Color(0xFF00BFA5) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : Color(0xFF00BFA5),
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              isPrimary
                  ? BorderSide.none
                  : BorderSide(color: Color(0xFF00BFA5), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (medicine.status == 'active'
                      ? Color(0xFF00BFA5)
                      : Colors.grey[400])!
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.medication_rounded,
              color:
                  medicine.status == 'active'
                      ? Color(0xFF00BFA5)
                      : Colors.grey[600],
              size: 24,
            ),
          ),
          title: Text(
            medicine.brandName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '${medicine.genericName} • ${medicine.dosage}mg',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${medicine.sellPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00BFA5),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.expand_more, color: Colors.grey[400]),
            ],
          ),
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow('NDC', medicine.ndc),
                  _buildDetailRow('Dosage', '${medicine.dosage}mg'),
                  _buildDetailRow('Expiry', medicine.expDate),
                  _buildDetailRow('Status', medicine.status.toUpperCase()),
                  _buildDetailRow(
                    'Purchase',
                    '\$${medicine.purchasePrice.toStringAsFixed(2)}',
                  ),
                  _buildDetailRow('Supplier ID', '${medicine.supID}'),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editMedicine(medicine),
                          icon: Icon(Icons.edit_outlined, size: 18),
                          label: Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF00BFA5),
                            side: BorderSide(color: Color(0xFF00BFA5)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              () => _deleteMedicine(
                                medicine.id!,
                                medicine.brandName,
                              ),
                          icon: Icon(Icons.delete_outline, size: 18),
                          label: Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[400],
                            side: BorderSide(color: Colors.red[400]!),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[900],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Medicine Dialog
class EditMedicineDialog extends StatefulWidget {
  final Medicine medicine;
  final Function(Medicine) onSave;

  EditMedicineDialog({required this.medicine, required this.onSave});

  @override
  _EditMedicineDialogState createState() => _EditMedicineDialogState();
}

class _EditMedicineDialogState extends State<EditMedicineDialog> {
  late TextEditingController ndcController;
  late TextEditingController brandNameController;
  late TextEditingController genericNameController;
  late TextEditingController dosageController;
  late TextEditingController expDateController;
  late TextEditingController purchasePriceController;
  late TextEditingController sellPriceController;
  late TextEditingController supIDController;
  late String selectedStatus;

  @override
  void initState() {
    super.initState();
    ndcController = TextEditingController(text: widget.medicine.ndc);
    brandNameController = TextEditingController(
      text: widget.medicine.brandName,
    );
    genericNameController = TextEditingController(
      text: widget.medicine.genericName,
    );
    dosageController = TextEditingController(
      text: widget.medicine.dosage.toString(),
    );
    expDateController = TextEditingController(text: widget.medicine.expDate);
    purchasePriceController = TextEditingController(
      text: widget.medicine.purchasePrice.toString(),
    );
    sellPriceController = TextEditingController(
      text: widget.medicine.sellPrice.toString(),
    );
    supIDController = TextEditingController(
      text: widget.medicine.supID.toString(),
    );
    selectedStatus = widget.medicine.status;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFF00BFA5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Edit Medicine',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildTextField(ndcController, 'NDC', Icons.tag_rounded),
                    SizedBox(height: 16),
                    _buildTextField(
                      brandNameController,
                      'Brand Name',
                      Icons.medication_rounded,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      genericNameController,
                      'Generic Name',
                      Icons.science_rounded,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      dosageController,
                      'Dosage (mg)',
                      Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      expDateController,
                      'Expiry Date',
                      Icons.calendar_today_rounded,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      purchasePriceController,
                      'Purchase Price',
                      Icons.attach_money_rounded,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      sellPriceController,
                      'Sell Price',
                      Icons.sell_rounded,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      supIDController,
                      'Supplier ID',
                      Icons.business_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFF00BFA5),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items:
                            ['active', 'inactive']
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status.toUpperCase()),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() => selectedStatus = value!);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final updated = Medicine(
                          id: widget.medicine.id,
                          ndc: ndcController.text,
                          brandName: brandNameController.text,
                          genericName: genericNameController.text,
                          dosage: double.tryParse(dosageController.text) ?? 0.0,
                          expDate: expDateController.text,
                          status: selectedStatus,
                          purchasePrice:
                              double.tryParse(purchasePriceController.text) ??
                              0.0,
                          sellPrice:
                              double.tryParse(sellPriceController.text) ?? 0.0,
                          supID: int.tryParse(supIDController.text) ?? 0,
                          fileType: widget.medicine.fileType,
                          sourceFile: widget.medicine.sourceFile,
                          uploadTimestamp: widget.medicine.uploadTimestamp,
                          uploadedAt: widget.medicine.uploadedAt,
                        );
                        widget.onSave(updated);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00BFA5),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF00BFA5)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
