import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import '../models/models.dart';
import 'supabase_service.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();
  SupabaseService get _supabase=>SupabaseService.instance;
  bool get isAvailable=>_supabase.auth!=null;
  User? get currentUser=>_supabase.currentUser;
  bool get isAuthenticated=>_supabase.isAuthenticated;
  Stream<AuthState> get onAuthStateChange=>_supabase.onAuthStateChange;
  static final RegExp _strongEightCharPassword=RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8}$');
  static String? validatePassword(String password){if(password.length!=8)return 'Password must be exactly 8 characters.';if(!_strongEightCharPassword.hasMatch(password))return 'Password must contain uppercase, lowercase, number, and special character.';return null;}
  Future<AuthResult> signUp({required String email,required String password,String? name}) async {if(!isAvailable)return AuthResult.failure('Authentication unavailable. Please check your connection and try again.');final e=validatePassword(password);if(e!=null)return AuthResult.failure(e);try{final r=await _supabase.auth!.signUp(email:email,password:password,data:name!=null&&name.isNotEmpty?{'name':name}:null);final u=r.user;if(u==null)return AuthResult.failure('Account creation failed: no user returned.');await DatabaseService.instance.upsertProfile(UserProfile(id:u.id,name:name!=null&&name.isNotEmpty?name:'User'));return AuthResult.success(u);}on AuthException catch(e){return AuthResult.failure(e.message);}catch(_){return AuthResult.failure('Account created, but profile synchronization failed. Please try signing in again.');}}
  Future<AuthResult> signIn({required String email,required String password}) async {if(!isAvailable)return AuthResult.failure('Authentication unavailable. Please check your connection and try again.');try{final r=await _supabase.auth!.signInWithPassword(email:email,password:password);if(r.user!=null)return AuthResult.success(r.user!);return AuthResult.failure('Sign in failed: no user returned.');}on AuthException catch(e){return AuthResult.failure(e.message);}catch(_){return AuthResult.failure('Sign in failed. Please try again.');}}
  Future<AuthResult> signInAnonymously() async {if(!isAvailable)return AuthResult.failure('Authentication unavailable. Please check your connection and try again.');try{final r=await _supabase.auth!.signInAnonymously();if(r.user!=null)return AuthResult.success(r.user!);return AuthResult.failure('Anonymous sign in failed.');}on AuthException catch(e){return AuthResult.failure(e.message);}catch(_){return AuthResult.failure('Anonymous sign in failed.');}}
  Future<void> signOut() async{if(!isAvailable)return;try{await _supabase.auth!.signOut();}catch(e){debugPrint('Sign out error: $e');}}
  Future<bool> resetPassword(String email) async{if(!isAvailable)return false;try{await _supabase.auth!.resetPasswordForEmail(email);return true;}catch(_){return false;}}
}
class AuthResult{final bool success;final User? user;final String? errorMessage;AuthResult.success(this.user):success=true,errorMessage=null;AuthResult.failure(this.errorMessage):success=false,user=null;}
