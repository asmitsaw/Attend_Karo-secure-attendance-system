-- Delete existing users (if any)
DELETE FROM students;
DELETE FROM users;

-- Create faculty user with correct password hash for 'password123'
INSERT INTO users (username, password_hash, name, role, department) 
VALUES ('faculty1', '$2a$10$h4UsU2KwK51x73bbzVpBD8.q2LnQ/ZkvVZrT2n6H0o2uk4p0uD7ISa', 'Dr. John Smith', 'FACULTY', 'Computer Science');

-- Create student user with correct password hash for 'password123'
INSERT INTO users (username, password_hash, name, role) 
VALUES ('student1', '$2a$10$h4UsU2KwK51x73bbzVpBD8.q2LnQ/ZkvVZrT2n6H0o2uk4p0uD7ISa', 'Alice Johnson', 'STUDENT');

-- Add student details
INSERT INTO students (id, roll_number) 
SELECT id, '001' FROM users WHERE username = 'student1';

-- Verify users were created
SELECT username, name, role FROM users;
