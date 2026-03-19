import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_task_screen.dart';
import 'extra_screens.dart';

class Task {
  final String id;
  final String title;
  final String time;
  final String timeColor; // "green" | "beige"
  final bool completed;
  final String userName;
  final String category;
  final String? imageUrl;
  final String description;

  Task({
    required this.id,
    required this.title,
    required this.time,
    required this.timeColor,
    required this.completed,
    required this.userName,
    this.category = "more",
    this.imageUrl,
    this.description = "",
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      timeColor: json['timeColor']?.toString() ?? 'green',
      completed: json['completed'] == true,
      userName: json['user_name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'more',
      imageUrl: json['image_url']?.toString(),
      description: json['description']?.toString() ?? '',
    );
  }
}

class TaskDashboardScreen extends StatefulWidget {
  final String userName;
  const TaskDashboardScreen({Key? key, required this.userName}) : super(key: key);

  @override
  State<TaskDashboardScreen> createState() => _TaskDashboardScreenState();
}

class _TaskDashboardScreenState extends State<TaskDashboardScreen> {
  bool _loading = true;
  List<Task> _tasks = [];

  // Hardcoded UI fallback list to match the Next.js visual exactly.
  final List<Task> _fallbackTasks = [
    Task(id: '1', title: "Morning Workout", time: "8 A.M", timeColor: "green", completed: false, userName: ''),
    Task(id: '2', title: "Reading Book", time: "10 A.M", timeColor: "beige", completed: false, userName: ''),
    Task(id: '3', title: "Job Tasks", time: "11 A.M", timeColor: "beige", completed: false, userName: ''),
    Task(id: '4', title: "Eating Breakfast", time: "6 A.M", timeColor: "green", completed: true, userName: ''),
    Task(id: '5', title: "Coding Session", time: "1 P.M", timeColor: "beige", completed: false, userName: ''),
  ];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    try {
      final data = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('user_name', widget.userName);
          
      final List<Task> fetchedTasks = (data as List<dynamic>).map((t) => Task.fromJson(t as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _tasks = fetchedTasks;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tasks. Using fallback data. Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    // 1. Optimistic Update directly in memory for immediate visual feedback
    setState(() {
      // Intentar actualizar en _tasks
      var index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = Task(
          id: task.id,
          title: task.title,
          time: task.time,
          timeColor: task.timeColor,
          completed: !task.completed,
          userName: task.userName,
        );
      } else {
        // En caso de que se esté usando _fallbackTasks
        index = _fallbackTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _fallbackTasks[index] = Task(
            id: task.id,
            title: task.title,
            time: task.time,
            timeColor: task.timeColor,
            completed: !task.completed,
            userName: task.userName,
          );
        }
      }
    });

    try {
      if (task.id.length > 5) { // Arbitrary check for real UUIDs
        await Supabase.instance.client
            .from('tasks')
            .update({'completed': !task.completed})
            .eq('id', task.id);
      }
          
      // Si quieres refrescar desde la BD, descomenta la siguiente línea:
      // _fetchTasks(); 
    } catch (e) {
      debugPrint("Error updating task (probablemente la tabla no exista): $e");
      // Mantenemos la palomita localmente para que la interacción siga siendo fluida 
      // y la tarea quede marcada visualmente aunque haya error en BD.
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Guardado como Demo (Error BD: $e)')),
         );
      }
    }
  }

  void _navigateToAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTaskScreen(userName: widget.userName)),
    ).then((_) {
      // Reload the tasks when returning from AddTaskScreen
      _fetchTasks();
    });
  }

  void _navigateToEditTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTaskScreen(
        userName: widget.userName,
        taskToEdit: {
          'id': task.id,
          'title': task.title,
          'description': task.description,
          'time': task.time,
          'timeColor': task.timeColor,
          'category': task.category,
          'completed': task.completed,
          'image_url': task.imageUrl,
        },
      )),
    ).then((_) {
      _fetchTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksToDisplay = _tasks.isNotEmpty ? _tasks : _fallbackTasks;

    // ----- CÁLCULOS DINÁMICOS -----
    final totalTasks = tasksToDisplay.length;
    final completedTasks = tasksToDisplay.where((t) => t.completed).length;
    final pendingTasks = totalTasks - completedTasks;
    final double percent = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final int percentInt = (percent * 100).toInt();
    // ------------------------------

    return Scaffold(
      backgroundColor: const Color(0xFF2ECC94),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Container(
            width: 360,
            constraints: const BoxConstraints(maxWidth: 400),
            // bg-white rounded-[40px] shadow-2xl
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Hola,",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                widget.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF2ECC94)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Weekly Tasks Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Circular Progress
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: percent,
                                  strokeWidth: 10,
                                  backgroundColor: const Color(0xFFE8F5F0),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF2ECC94)),
                                  strokeCap: StrokeCap.round,
                                ),
                                Center(
                                  child: Text(
                                    "$percentInt%",
                                    style: const TextStyle(
                                        color: Color(0xFF2ECC94),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Stats
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Text(
                                      "Weekly Tasks",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$totalTasks",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500, color: Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$pendingTasks",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Today Tasks Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today Tasks",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "${_tasks.where((t) => t.completed).length} of ${_tasks.length}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Bar
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: LinearProgressIndicator(
                          value: _tasks.isEmpty 
                            ? 0.0 
                            : _tasks.where((t) => t.completed).length / _tasks.length,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF2ECC94)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Task List
                      Container(
                        height: 280,
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _loading && _tasks.isEmpty
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC94))) 
                          : tasksToDisplay.isEmpty 
                            ? const Center(
                                child: Text("No tasks yet. Create one!", style: TextStyle(color: Colors.grey))
                              )
                            : ListView.builder(
                                itemCount: tasksToDisplay.length,
                                itemBuilder: (context, index) {
                                  final task = tasksToDisplay[index];
                                  return GestureDetector(
                                    onTap: () => _toggleTaskCompletion(task),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: task.completed ? const Color(0xFF2ECC94) : Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: task.completed ? const Color(0xFF2ECC94) : Colors.grey.shade300,
                                                width: 2,
                                              ),
                                            ),
                                            child: task.completed
                                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  task.title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: task.completed ? Colors.grey : Colors.black87,
                                                    fontSize: 15,
                                                    decoration: task.completed ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                                if (task.imageUrl != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Image.network(
                                                        task.imageUrl!,
                                                        height: 60,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (c, e, s) => const Text("[Imagen no cargable]"),
                                                      ),
                                                    ),
                                                  )
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: task.timeColor == 'green'
                                                  ? const Color(0xFFE8F5F0)
                                                  : const Color(0xFFFDF6E3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              task.time,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: task.timeColor == 'green'
                                                    ? const Color(0xFF2ECC94)
                                                    : const Color(0xFFC4A962),
                                              ),
                                            ),
                                          ),
                                          // Botón de editar
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                                            onPressed: () => _navigateToEditTask(task),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                
                // Bottom Navigation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF5F5F5))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.home_outlined, color: Color(0xFF2ECC94)),
                        iconSize: 28,
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksHistoryScreen()));
                        },
                        icon: const Icon(Icons.description_outlined, color: Colors.grey),
                        iconSize: 28,
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const GesturesScreen()));
                        },
                        icon: const Icon(Icons.back_hand_outlined, color: Colors.grey),
                        iconSize: 28,
                      ),
                      GestureDetector(
                        onTap: _navigateToAddTask,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC94),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2ECC94).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 24),
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
