import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery List App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GroceryListScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'An error occurred')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Enter an email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) =>
                    value!.isEmpty ? 'Enter a password' : null,
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton(
                          child: Text('Login'),
                          onPressed: _login,
                        ),
                        TextButton(
                          child: Text('Register'),
                          onPressed: _register,
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroceryListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Grocery List'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groceries')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

          List<DocumentSnapshot> documents = snapshot.data!.docs;
          documents.sort((a, b) {
            bool isDoneA =
                (a.data() as Map<String, dynamic>)['isDone'] ?? false;
            bool isDoneB =
                (b.data() as Map<String, dynamic>)['isDone'] ?? false;
            if (isDoneA == isDoneB) return 0;
            if (isDoneA) return 1;
            return -1;
          });

          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> data =
                  documents[index].data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: Checkbox(
                    value: data['isDone'] ?? false,
                    onChanged: (bool? value) {
                      FirebaseFirestore.instance
                          .collection('groceries')
                          .doc(documents[index].id)
                          .update({'isDone': value});
                    },
                  ),
                  title: Text(
                    data['item'],
                    style: TextStyle(
                      decoration: data['isDone'] == true
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () =>
                        _showEditItemDialog(context, documents[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _showAddItemDialog(context),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    String newItem = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Grocery Item'),
          content: TextField(
            onChanged: (value) {
              newItem = value;
            },
            decoration: InputDecoration(hintText: "Enter grocery item"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                if (newItem.isNotEmpty) {
                  FirebaseFirestore.instance.collection('groceries').add({
                    'item': newItem,
                    'isDone': false,
                    'userId': FirebaseAuth.instance.currentUser!.uid,
                  });
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditItemDialog(BuildContext context, DocumentSnapshot document) {
    String updatedItem = document['item'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Grocery Item'),
          content: TextField(
            onChanged: (value) {
              updatedItem = value;
            },
            decoration: InputDecoration(hintText: "Enter new item name"),
            controller: TextEditingController(text: updatedItem),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Update'),
              onPressed: () {
                if (updatedItem.isNotEmpty) {
                  FirebaseFirestore.instance
                      .collection('groceries')
                      .doc(document.id)
                      .update({'item': updatedItem});
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
