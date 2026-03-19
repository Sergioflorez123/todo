import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CategoryItem {
  final String id;
  final String label;

  CategoryItem(this.id, this.label);
}

final List<CategoryItem> categories = [
  CategoryItem("healthy", "Healthy"),
  CategoryItem("design", "Design"),
  CategoryItem("job", "Job"),
  CategoryItem("education", "Education"),
  CategoryItem("sport", "Sport"),
  CategoryItem("more", "More"),
];

class AddTaskScreen extends StatefulWidget {
  final String userName;
  final Map<String, dynamic>? taskToEdit; // Si se pasa, estamos en modo "Editar"

  const AddTaskScreen({Key? key, required this.userName, this.taskToEdit}) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  String selectedCategory = "more";
  String selectedColor = "green"; // Default color "green" o "beige"
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  
  TimeOfDay? _selectedTime;
  XFile? _selectedImage; 
  String? _existingImageUrl; // Para mostrar si ya tenía una imagen cargada
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      _titleController.text = widget.taskToEdit!['title'] ?? '';
      _descController.text = widget.taskToEdit!['description'] ?? '';
      selectedCategory = widget.taskToEdit!['category'] ?? 'more';
      selectedColor = widget.taskToEdit!['timeColor'] ?? 'green';
      _existingImageUrl = widget.taskToEdit!['image_url'];

      final timeString = widget.taskToEdit!['time'] as String?;
      if (timeString != null && timeString.contains(' ')) {
        final parts = timeString.split(' ');
        int hour = int.tryParse(parts[0]) ?? 12;
        if (parts[1] == "P.M" && hour < 12) hour += 12;
        if (parts[1] == "A.M" && hour == 12) hour = 0;
        _selectedTime = TimeOfDay(hour: hour, minute: 0);
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.camera_alt, size: 40, color: Color(0xFF2ECC94)),
                    SizedBox(height: 8),
                    Text("Tomar Foto"),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.photo_library, size: 40, color: Color(0xFF2ECC94)),
                    SizedBox(height: 8),
                    Text("Galería"),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      debugPrint("Error seleccionando foto: $e");
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handleConfirmAdd() async {
    if (_titleController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el título de la tarea.')),
      );
      return;
    }
    if (_selectedTime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona a qué hora realizarás la actividad.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final hour = _selectedTime!.hourOfPeriod == 0 ? 12 : _selectedTime!.hourOfPeriod;
      final period = _selectedTime!.period == DayPeriod.am ? "A.M" : "P.M";
      final timeString = "$hour $period";

      String? uploadedImageUrl = _existingImageUrl; // Mantener la anterior si no se seleccionó nueva

      if (_selectedImage != null) {
        final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.name.replaceAll(' ', '_')}';
        try {
          final bytes = await _selectedImage!.readAsBytes();
          await Supabase.instance.client.storage.from('images').uploadBinary(safeFileName, bytes);
          uploadedImageUrl = Supabase.instance.client.storage.from('images').getPublicUrl(safeFileName);
        } catch (storageError) {
          debugPrint("Error Storage: $storageError");
        }
      }
      
      final taskData = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': selectedCategory,
        'time': timeString,
        'timeColor': selectedColor, // Usando el color seleccionado por el usuario
        'completed': widget.taskToEdit?['completed'] ?? false,
        'user_name': widget.userName,
        if (uploadedImageUrl != null) 'image_url': uploadedImageUrl,
      };

      if (widget.taskToEdit != null && widget.taskToEdit!['id'] != null) {
         // Modo EDICIÓN
         await Supabase.instance.client.from('tasks').update(taskData).eq('id', widget.taskToEdit!['id']);
      } else {
         // Modo CREACIÓN
         await Supabase.instance.client.from('tasks').insert(taskData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving task: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.pop(context, false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFF2ECC94),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () { if (!_isLoading) Navigator.pop(context); },
                        icon: const Icon(Icons.arrow_back, color: Colors.black87),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Expanded(
                        child: Text(
                          isEditing ? "Edit Task" : "Adding Task",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Task Title Input
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(16)),
                        child: TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            hintText: "Task Title", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),

                      // Description Input
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(16)),
                        child: TextField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: "Description", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),

                      // Select Time 
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_outlined, color: Color(0xFF2ECC94), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedTime != null ? "Hora: ${_selectedTime!.format(context)}" : "Seleccionar Hora",
                                  style: const TextStyle(color: Color(0xFF2ECC94), fontWeight: FontWeight.w500),
                                ),
                              ),
                              Icon(Icons.chevron_right, color: const Color(0xFF2ECC94).withOpacity(0.5)),
                            ],
                          ),
                        ),
                      ),

                      // Image Selection
                      GestureDetector(
                        onTap: _isLoading ? null : _showImageOptions,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: const Color(0xFFE8F5F0), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.add_a_photo, color: Color(0xFF2ECC94), size: 12),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedImage != null 
                                     ? "Img lista: ${_selectedImage!.name}" 
                                     : (_existingImageUrl != null ? "Imagen actual ya guardada (Toca para cambiar)" : "Añadir / Tomar Foto"),
                                  style: const TextStyle(color: Color(0xFF2ECC94), fontWeight: FontWeight.w500),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Choose Task Color
                      const Text("Selecciona Color Visual", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => selectedColor = "green"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5F0),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: selectedColor == "green" ? const Color(0xFF2ECC94) : Colors.transparent, width: 2),
                              ),
                              child: const Text("Verde", style: TextStyle(color: Color(0xFF2ECC94), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => setState(() => selectedColor = "beige"),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDF6E3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: selectedColor == "beige" ? const Color(0xFFC4A962) : Colors.transparent, width: 2),
                              ),
                              child: const Text("Beige", style: TextStyle(color: Color(0xFFC4A962), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Choose Category
                      const Text("Categoría", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12, runSpacing: 12,
                        children: categories.map((cat) {
                          final isSelected = selectedCategory == cat.id;
                          return GestureDetector(
                            onTap: () => setState(() => selectedCategory = cat.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2ECC94) : const Color(0xFFFAFAFA),
                                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                cat.label,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : Colors.grey.shade600),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Confirm Button
                      GestureDetector(
                        onTap: _isLoading ? null : _handleConfirmAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(color: const Color(0xFF2A5B52), borderRadius: BorderRadius.circular(16)),
                          alignment: Alignment.center,
                          child: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                isEditing ? "Save Changes" : "Confirm Adding",
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
      ),
    );
  }
}
