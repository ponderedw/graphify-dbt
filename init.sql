-- ============================================================
-- High School Analytics - Raw Data Seed
-- Creates schema and populates all source tables
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw_edu;

-- ============================================================
-- DEPARTMENTS
-- ============================================================
CREATE TABLE raw_edu.departments (
    department_id   SERIAL PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    department_code VARCHAR(10)  NOT NULL,
    head_faculty_id INT,
    budget          NUMERIC(12,2),
    building_location VARCHAR(100),
    created_at      TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.departments (department_name, department_code, head_faculty_id, budget, building_location) VALUES
('Mathematics',         'MATH', 1,  2500000, 'North Hall'),
('Science',             'SCI',  6,  3200000, 'Science Wing'),
('English & Literature','ENG',  11, 1800000, 'Humanities Building'),
('History & Social Studies', 'HIST', 14, 1500000, 'Humanities Building'),
('Physical Education',  'PE',   18, 900000,  'Gymnasium');


-- ============================================================
-- FACULTY
-- ============================================================
CREATE TABLE raw_edu.faculty (
    faculty_id         SERIAL PRIMARY KEY,
    first_name         VARCHAR(50) NOT NULL,
    last_name          VARCHAR(50) NOT NULL,
    email              VARCHAR(100) UNIQUE NOT NULL,
    department_id      INT REFERENCES raw_edu.departments(department_id),
    position           VARCHAR(50),
    salary             NUMERIC(10,2),
    hire_date          DATE,
    office_number      VARCHAR(20),
    research_interests TEXT,
    created_at         TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.faculty (first_name, last_name, email, department_id, position, salary, hire_date, office_number, research_interests) VALUES
('Alice',   'Chen',      'a.chen@school.edu',       1, 'Professor',           105000, '2008-08-15', 'N101', 'Applied algebra'),
('Brian',   'Kowalski',  'b.kowalski@school.edu',   1, 'Associate Professor',  88000, '2012-01-10', 'N102', 'Statistics and probability'),
('Carla',   'Reyes',     'c.reyes@school.edu',       1, 'Assistant Professor',  72000, '2018-08-20', 'N103', 'Calculus pedagogy'),
('David',   'Osei',      'd.osei@school.edu',         1, 'Lecturer',             58000, '2020-09-01', 'N104', NULL),
('Erin',    'Nakamura',  'e.nakamura@school.edu',    1, 'Lecturer',             56000, '2021-01-15', 'N105', NULL),
('Frank',   'Liu',       'f.liu@school.edu',          2, 'Professor',           112000, '2005-08-10', 'S201', 'Molecular biology'),
('Grace',   'Diallo',    'g.diallo@school.edu',       2, 'Associate Professor',  91000, '2011-08-22', 'S202', 'Environmental science'),
('Henry',   'Patel',     'h.patel@school.edu',        2, 'Assistant Professor',  75000, '2017-09-05', 'S203', 'Physics education'),
('Irene',   'Torres',    'i.torres@school.edu',       2, 'Lecturer',             60000, '2019-08-19', 'S204', NULL),
('James',   'Wu',        'j.wu@school.edu',            2, 'Lecturer',             57000, '2022-01-10', 'S205', NULL),
('Karen',   'Okafor',    'k.okafor@school.edu',       3, 'Professor',            98000, '2007-08-14', 'H301', 'Narrative theory'),
('Leo',     'Svensson',  'l.svensson@school.edu',    3, 'Associate Professor',  82000, '2014-08-18', 'H302', 'Modern literature'),
('Mia',     'Fontaine',  'm.fontaine@school.edu',    3, 'Lecturer',             59000, '2020-01-06', 'H303', NULL),
('Nathan',  'Adeyemi',   'n.adeyemi@school.edu',     4, 'Professor',            95000, '2009-08-17', 'H401', 'Civil rights history'),
('Olivia',  'Brooks',    'o.brooks@school.edu',       4, 'Associate Professor',  80000, '2015-08-24', 'H402', 'World history'),
('Paul',    'Kim',       'p.kim@school.edu',           4, 'Lecturer',             57000, '2021-08-23', 'H403', NULL),
('Rachel',  'Singh',     'r.singh@school.edu',        4, 'Lecturer',             55000, '2022-08-22', 'H404', NULL),
('Samuel',  'Ortega',    's.ortega@school.edu',       5, 'Professor',            78000, '2010-08-16', 'G501', 'Sports medicine'),
('Tanya',   'Brennan',   't.brennan@school.edu',     5, 'Lecturer',             54000, '2019-08-20', 'G502', NULL),
('Uma',     'Grant',     'u.grant@school.edu',        5, 'Lecturer',             52000, '2023-01-09', 'G503', NULL);

UPDATE raw_edu.departments SET head_faculty_id = 1  WHERE department_id = 1;
UPDATE raw_edu.departments SET head_faculty_id = 6  WHERE department_id = 2;
UPDATE raw_edu.departments SET head_faculty_id = 11 WHERE department_id = 3;
UPDATE raw_edu.departments SET head_faculty_id = 14 WHERE department_id = 4;
UPDATE raw_edu.departments SET head_faculty_id = 18 WHERE department_id = 5;


-- ============================================================
-- STUDENTS
-- ============================================================
CREATE TABLE raw_edu.students (
    student_id      SERIAL PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(100) UNIQUE NOT NULL,
    date_of_birth   DATE,
    enrollment_date DATE,
    graduation_date DATE,
    student_status  VARCHAR(20) DEFAULT 'active',
    gpa             NUMERIC(4,2),
    major_id        INT REFERENCES raw_edu.departments(department_id),
    advisor_id      INT REFERENCES raw_edu.faculty(faculty_id),
    address_id      INT,
    created_at      TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.students (first_name, last_name, email, date_of_birth, enrollment_date, graduation_date, student_status, gpa, major_id, advisor_id) VALUES
('Aisha',   'Mohammed',  'a.mohammed@students.edu',  '2005-03-12', '2021-09-01', NULL,         'active',    3.85, 1, 1),
('Ben',     'Hartley',   'b.hartley@students.edu',   '2004-07-22', '2020-09-01', '2024-06-01', 'graduated', 3.60, 2, 6),
('Cleo',    'Vasquez',   'c.vasquez@students.edu',   '2005-11-05', '2021-09-01', NULL,         'active',    2.90, 3, 11),
('Dylan',   'Park',      'd.park@students.edu',      '2006-01-30', '2022-09-01', NULL,         'active',    3.45, 1, 2),
('Eva',     'Johansson', 'e.johansson@students.edu', '2005-08-14', '2021-09-01', NULL,         'active',    1.85, 2, 7),
('Finn',    'O''Brien',  'f.obrien@students.edu',    '2004-04-18', '2020-09-01', '2024-06-01', 'graduated', 2.75, 4, 14),
('Gina',    'Ferreira',  'g.ferreira@students.edu',  '2006-06-09', '2022-09-01', NULL,         'active',    3.72, 2, 8),
('Hassan',  'Al-Amin',   'h.alamin@students.edu',    '2005-02-28', '2021-09-01', NULL,         'active',    3.10, 3, 12),
('Isla',    'McGregor',  'i.mcgregor@students.edu',  '2006-09-17', '2022-09-01', NULL,         'active',    2.55, 1, 3),
('Jake',    'Thornton',  'j.thornton@students.edu',  '2004-12-03', '2020-09-01', NULL,         'active',    2.20, 4, 15),
('Kira',    'Tanaka',    'k.tanaka@students.edu',    '2005-05-21', '2021-09-01', NULL,         'active',    3.92, 1, 1),
('Liam',    'Nkosi',     'l.nkosi@students.edu',     '2005-10-07', '2021-09-01', NULL,         'active',    2.40, 2, 7),
('Maya',    'Dubois',    'm.dubois@students.edu',    '2006-03-25', '2022-09-01', NULL,         'active',    3.55, 3, 11),
('Noah',    'Eriksson',  'n.eriksson@students.edu',  '2004-08-11', '2020-09-01', '2024-06-01', 'graduated', 3.20, 1, 2),
('Ona',     'Petrov',    'o.petrov@students.edu',    '2005-12-29', '2021-09-01', NULL,         'active',    1.60, 4, 16),
('Pierce',  'Dlamini',   'p.dlamini@students.edu',   '2006-07-04', '2022-09-01', NULL,         'active',    3.30, 2, 6),
('Quinn',   'Lambert',   'q.lambert@students.edu',   '2005-04-16', '2021-09-01', NULL,         'active',    2.80, 5, 18),
('Rosa',    'Alves',     'r.alves@students.edu',     '2006-11-02', '2022-09-01', NULL,         'active',    3.65, 3, 13),
('Sam',     'Iwata',     's.iwata@students.edu',     '2005-06-20', '2021-09-01', NULL,         'active',    3.00, 1, 4),
('Tina',    'Oduya',     't.oduya@students.edu',     '2006-01-13', '2022-09-01', NULL,         'active',    2.15, 2, 9),
('Umar',    'Castillo',  'u.castillo@students.edu',  '2004-09-08', '2020-09-01', NULL,         'active',    3.40, 4, 14),
('Vera',    'Hansson',   'v.hansson@students.edu',   '2005-07-31', '2021-09-01', NULL,         'active',    3.78, 2, 6),
('Will',    'Okonkwo',   'w.okonkwo@students.edu',   '2006-02-19', '2022-09-01', NULL,         'active',    2.95, 1, 5),
('Xena',    'Martín',    'x.martin@students.edu',    '2005-09-23', '2021-09-01', NULL,         'active',    3.15, 3, 11),
('Yusuf',   'Larsen',    'y.larsen@students.edu',    '2004-11-14', '2020-09-01', NULL,         'active',    2.50, 5, 19),
('Zara',    'Ito',       'z.ito@students.edu',       '2006-04-07', '2022-09-01', NULL,         'active',    3.88, 1, 1),
('Aaron',   'Mensah',    'aa.mensah@students.edu',   '2005-01-26', '2021-09-01', NULL,         'inactive',  1.40, 2, 10),
('Bella',   'Nguyen',    'be.nguyen@students.edu',   '2006-08-15', '2022-09-01', NULL,         'active',    3.25, 4, 15),
('Carlos',  'Osei',      'ca.osei@students.edu',     '2005-03-04', '2021-09-01', NULL,         'active',    2.70, 3, 12),
('Diana',   'Popescu',   'di.popescu@students.edu',  '2006-06-28', '2022-09-01', NULL,         'active',    3.50, 2, 8);


-- ============================================================
-- COURSES
-- ============================================================
CREATE TABLE raw_edu.courses (
    course_id             SERIAL PRIMARY KEY,
    course_code           VARCHAR(20) UNIQUE NOT NULL,
    course_name           VARCHAR(150) NOT NULL,
    description           TEXT,
    credits               INT,
    department_id         INT REFERENCES raw_edu.departments(department_id),
    prerequisite_course_id INT,
    difficulty_level      INT CHECK (difficulty_level BETWEEN 1 AND 5),
    created_at            TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.courses (course_code, course_name, description, credits, department_id, prerequisite_course_id, difficulty_level) VALUES
('MATH101', 'Pre-Calculus',                  'Foundations of algebraic and trigonometric concepts',          3, 1, NULL, 1),
('MATH201', 'Calculus I',                    'Limits, derivatives, and integrals',                           4, 1, 1,    3),
('MATH202', 'Calculus II',                   'Integration techniques and series',                            4, 1, 2,    4),
('MATH301', 'Statistics',                    'Descriptive and inferential statistics',                       3, 1, NULL, 2),
('SCI101',  'Biology',                       'Cell biology, genetics, and ecosystems',                       3, 2, NULL, 1),
('SCI102',  'Chemistry',                     'Atomic structure, reactions, and stoichiometry',               3, 2, NULL, 2),
('SCI201',  'Physics I',                     'Mechanics, kinematics, and energy',                            3, 2, NULL, 2),
('SCI202',  'Physics II',                    'Electricity, magnetism, and waves',                            3, 2, 7,    3),
('SCI301',  'AP Biology',                    'Advanced biology with laboratory component',                   4, 2, 5,    4),
('ENG101',  'Composition I',                 'Foundational writing and rhetoric',                            3, 3, NULL, 1),
('ENG201',  'American Literature',           'Survey of American fiction and poetry',                       3, 3, 10,   2),
('ENG202',  'World Literature',              'Global literary traditions',                                   3, 3, 10,   2),
('ENG301',  'AP English Literature',         'Advanced literary analysis and essay writing',                4, 3, 11,   4),
('HIST101', 'World History',                 'Political and cultural history from ancient to modern times',  3, 4, NULL, 1),
('HIST201', 'US History',                    'American history from colonial era to present',                3, 4, 14,   2),
('HIST301', 'AP US History',                 'Advanced US history with primary source analysis',             4, 4, 15,   4),
('PE101',   'Physical Education I',          'Fitness fundamentals and team sports',                        1, 5, NULL, 1),
('PE201',   'Physical Education II',         'Advanced fitness and individual sports',                      1, 5, 17,   2),
('PE301',   'Health & Sports Science',       'Anatomy, nutrition, and sports performance',                  2, 5, NULL, 3);

UPDATE raw_edu.courses SET prerequisite_course_id = NULL WHERE prerequisite_course_id IS NOT NULL
    AND prerequisite_course_id NOT IN (SELECT course_id FROM raw_edu.courses);


-- ============================================================
-- SEMESTERS
-- ============================================================
CREATE TABLE raw_edu.semesters (
    semester_id   SERIAL PRIMARY KEY,
    semester_name VARCHAR(50) NOT NULL,
    academic_year VARCHAR(20) NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    is_current    BOOLEAN DEFAULT FALSE,
    created_at    TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.semesters (semester_name, academic_year, start_date, end_date, is_current) VALUES
('Fall 2022',   '2022-2023', '2022-08-29', '2022-12-16', FALSE),
('Spring 2023', '2022-2023', '2023-01-16', '2023-05-12', FALSE),
('Fall 2023',   '2023-2024', '2023-08-28', '2023-12-15', FALSE),
('Spring 2024', '2023-2024', '2024-01-15', '2024-05-10', FALSE),
('Fall 2024',   '2024-2025', '2024-08-26', '2024-12-13', TRUE),
('Spring 2025', '2024-2025', '2025-01-13', '2025-05-08', FALSE);


-- ============================================================
-- CLASS SESSIONS
-- ============================================================
CREATE TABLE raw_edu.class_sessions (
    session_id       SERIAL PRIMARY KEY,
    course_id        INT REFERENCES raw_edu.courses(course_id),
    faculty_id       INT REFERENCES raw_edu.faculty(faculty_id),
    semester_id      INT REFERENCES raw_edu.semesters(semester_id),
    session_date     DATE,
    session_time     TIME,
    room_id          VARCHAR(20),
    attendance_count INT,
    created_at       TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.class_sessions (course_id, faculty_id, semester_id, session_date, session_time, room_id, attendance_count) VALUES
-- MATH101 Fall 2023 (faculty 1)
(1, 1, 3, '2023-09-06', '08:00:00', 'N101', 28),
(1, 1, 3, '2023-09-11', '08:00:00', 'N101', 27),
(1, 1, 3, '2023-09-13', '08:00:00', 'N101', 29),
(1, 1, 3, '2023-09-18', '08:00:00', 'N101', 26),
(1, 1, 3, '2023-09-20', '08:00:00', 'N101', 28),
-- MATH201 Fall 2023 (faculty 2)
(2, 2, 3, '2023-09-06', '10:00:00', 'N102', 20),
(2, 2, 3, '2023-09-11', '10:00:00', 'N102', 19),
(2, 2, 3, '2023-09-13', '10:00:00', 'N102', 22),
-- MATH301 Spring 2024 (faculty 2)
(4, 2, 4, '2024-01-17', '10:00:00', 'N102', 18),
(4, 2, 4, '2024-01-22', '10:00:00', 'N102', 19),
(4, 2, 4, '2024-01-24', '10:00:00', 'N102', 17),
-- SCI101 Fall 2023 (faculty 6)
(5, 6, 3, '2023-09-07', '09:00:00', 'S201', 30),
(5, 6, 3, '2023-09-12', '09:00:00', 'S201', 29),
(5, 6, 3, '2023-09-14', '09:00:00', 'S201', 31),
(5, 6, 3, '2023-09-19', '09:00:00', 'S201', 28),
-- SCI102 Spring 2024 (faculty 7)
(6, 7, 4, '2024-01-16', '11:00:00', 'S202', 25),
(6, 7, 4, '2024-01-18', '11:00:00', 'S202', 24),
(6, 7, 4, '2024-01-23', '11:00:00', 'S202', 26),
-- SCI201 Fall 2023 (faculty 8)
(7, 8, 3, '2023-09-06', '13:00:00', 'S203', 22),
(7, 8, 3, '2023-09-08', '13:00:00', 'S203', 21),
(7, 8, 3, '2023-09-13', '13:00:00', 'S203', 23),
-- SCI301 Fall 2024 (faculty 6)
(9, 6, 5, '2024-09-04', '09:00:00', 'S201', 15),
(9, 6, 5, '2024-09-09', '09:00:00', 'S201', 14),
(9, 6, 5, '2024-09-11', '09:00:00', 'S201', 16),
-- ENG101 Fall 2023 (faculty 11)
(10, 11, 3, '2023-09-05', '14:00:00', 'H301', 30),
(10, 11, 3, '2023-09-07', '14:00:00', 'H301', 28),
(10, 11, 3, '2023-09-12', '14:00:00', 'H301', 29),
(10, 11, 3, '2023-09-14', '14:00:00', 'H301', 27),
-- ENG201 Spring 2024 (faculty 12)
(11, 12, 4, '2024-01-16', '15:00:00', 'H302', 20),
(11, 12, 4, '2024-01-18', '15:00:00', 'H302', 18),
(11, 12, 4, '2024-01-23', '15:00:00', 'H302', 19),
-- ENG301 Fall 2024 (faculty 11)
(13, 11, 5, '2024-08-28', '14:00:00', 'H301', 18),
(13, 11, 5, '2024-09-02', '14:00:00', 'H301', 17),
(13, 11, 5, '2024-09-04', '14:00:00', 'H301', 19),
-- HIST101 Fall 2023 (faculty 14)
(14, 14, 3, '2023-09-06', '08:00:00', 'H401', 32),
(14, 14, 3, '2023-09-08', '08:00:00', 'H401', 30),
(14, 14, 3, '2023-09-13', '08:00:00', 'H401', 31),
-- HIST201 Spring 2024 (faculty 15)
(15, 15, 4, '2024-01-17', '09:00:00', 'H402', 24),
(15, 15, 4, '2024-01-22', '09:00:00', 'H402', 22),
(15, 15, 4, '2024-01-24', '09:00:00', 'H402', 25),
-- HIST301 Fall 2024 (faculty 14)
(16, 14, 5, '2024-08-27', '08:00:00', 'H401', 16),
(16, 14, 5, '2024-09-03', '08:00:00', 'H401', 15),
(16, 14, 5, '2024-09-05', '08:00:00', 'H401', 17),
-- PE101 Fall 2023 (faculty 18)
(17, 18, 3, '2023-09-05', '10:00:00', 'G501', 35),
(17, 18, 3, '2023-09-07', '10:00:00', 'G501', 33),
(17, 18, 3, '2023-09-12', '10:00:00', 'G501', 34),
-- PE201 Spring 2024 (faculty 19)
(18, 19, 4, '2024-01-16', '10:00:00', 'G501', 28),
(18, 19, 4, '2024-01-18', '10:00:00', 'G501', 26),
(18, 19, 4, '2024-01-23', '10:00:00', 'G501', 27);


-- ============================================================
-- ENROLLMENTS
-- ============================================================
CREATE TABLE raw_edu.enrollments (
    enrollment_id        SERIAL PRIMARY KEY,
    student_id           INT REFERENCES raw_edu.students(student_id),
    course_id            INT REFERENCES raw_edu.courses(course_id),
    semester_id          INT REFERENCES raw_edu.semesters(semester_id),
    enrollment_date      DATE,
    completion_date      DATE,
    grade                VARCHAR(5),
    grade_points         NUMERIC(4,2),
    attendance_percentage NUMERIC(5,2),
    created_at           TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.enrollments (student_id, course_id, semester_id, enrollment_date, completion_date, grade, grade_points, attendance_percentage) VALUES
-- Fall 2022 enrollments
(6, 10, 1, '2022-08-25', '2022-12-16', 'B',  3.0,  88.0),
(6, 14, 1, '2022-08-25', '2022-12-16', 'C+', 2.3,  82.0),
(6, 17, 1, '2022-08-25', '2022-12-16', 'B+', 3.3,  95.0),
(14,1,  1, '2022-08-25', '2022-12-16', 'A-', 3.7,  93.0),
(14,10, 1, '2022-08-25', '2022-12-16', 'B+', 3.3,  91.0),
(14,14, 1, '2022-08-25', '2022-12-16', 'B',  3.0,  89.0),
(21,1,  1, '2022-08-25', '2022-12-16', 'B',  3.0,  87.0),
(21,10, 1, '2022-08-25', '2022-12-16', 'B+', 3.3,  90.0),
(21,14, 1, '2022-08-25', '2022-12-16', 'A-', 3.7,  94.0),
(25,17, 1, '2022-08-25', '2022-12-16', 'B',  3.0,  85.0),
(25,14, 1, '2022-08-25', '2022-12-16', 'C',  2.0,  78.0),
-- Spring 2023 enrollments
(6, 11, 2, '2023-01-10', '2023-05-12', 'C+', 2.3,  80.0),
(6, 15, 2, '2023-01-10', '2023-05-12', 'C',  2.0,  76.0),
(6, 18, 2, '2023-01-10', '2023-05-12', 'B-', 2.7,  88.0),
(14,2,  2, '2023-01-10', '2023-05-12', 'A',  4.0,  96.0),
(14,5,  2, '2023-01-10', '2023-05-12', 'A-', 3.7,  94.0),
(14,11, 2, '2023-01-10', '2023-05-12', 'B+', 3.3,  90.0),
(21,2,  2, '2023-01-10', '2023-05-12', 'B+', 3.3,  88.0),
(21,4,  2, '2023-01-10', '2023-05-12', 'A-', 3.7,  92.0),
(25,18, 2, '2023-01-10', '2023-05-12', 'C',  2.0,  75.0),
(25,4,  2, '2023-01-10', '2023-05-12', 'D',  1.0,  65.0),
-- Fall 2023 enrollments (the bulk)
(1, 1,  3, '2023-08-25', '2023-12-15', 'A',  4.0,  97.0),
(1, 5,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  95.0),
(1, 10, 3, '2023-08-25', '2023-12-15', 'A',  4.0,  98.0),
(1, 14, 3, '2023-08-25', '2023-12-15', 'A-', 3.7,  96.0),
(1, 17, 3, '2023-08-25', '2023-12-15', 'A',  4.0, 100.0),
(3, 10, 3, '2023-08-25', '2023-12-15', 'B',  3.0,  84.0),
(3, 14, 3, '2023-08-25', '2023-12-15', 'B+', 3.3,  87.0),
(3, 17, 3, '2023-08-25', '2023-12-15', 'A-', 3.7,  92.0),
(4, 1,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  94.0),
(4, 7,  3, '2023-08-25', '2023-12-15', 'B+', 3.3,  89.0),
(5, 5,  3, '2023-08-25', '2023-12-15', 'D',  1.0,  61.0),
(5, 10, 3, '2023-08-25', '2023-12-15', 'D+', 1.3,  68.0),
(5, 17, 3, '2023-08-25', '2023-12-15', 'C',  2.0,  72.0),
(7, 5,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  96.0),
(7, 7,  3, '2023-08-25', '2023-12-15', 'B+', 3.3,  91.0),
(8, 10, 3, '2023-08-25', '2023-12-15', 'B',  3.0,  85.0),
(8, 14, 3, '2023-08-25', '2023-12-15', 'B+', 3.3,  88.0),
(9, 1,  3, '2023-08-25', '2023-12-15', 'C+', 2.3,  79.0),
(9, 17, 3, '2023-08-25', '2023-12-15', 'B',  3.0,  83.0),
(11,1,  3, '2023-08-25', '2023-12-15', 'A+', 4.0, 100.0),
(11,5,  3, '2023-08-25', '2023-12-15', 'A',  4.0,  98.0),
(11,7,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  95.0),
(12,5,  3, '2023-08-25', '2023-12-15', 'C',  2.0,  74.0),
(12,10, 3, '2023-08-25', '2023-12-15', 'C+', 2.3,  78.0),
(15,14, 3, '2023-08-25', '2023-12-15', 'F',  0.0,  45.0),
(15,10, 3, '2023-08-25', '2023-12-15', 'D',  1.0,  62.0),
(15,17, 3, '2023-08-25', '2023-12-15', 'W',  NULL, 30.0),
(16,5,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  93.0),
(16,7,  3, '2023-08-25', '2023-12-15', 'B+', 3.3,  90.0),
(17,17, 3, '2023-08-25', '2023-12-15', 'B',  3.0,  86.0),
(18,10, 3, '2023-08-25', '2023-12-15', 'A',  4.0,  97.0),
(18,14, 3, '2023-08-25', '2023-12-15', 'A-', 3.7,  95.0),
(19,1,  3, '2023-08-25', '2023-12-15', 'B-', 2.7,  82.0),
(20,5,  3, '2023-08-25', '2023-12-15', 'C',  2.0,  73.0),
(20,10, 3, '2023-08-25', '2023-12-15', 'C+', 2.3,  77.0),
(22,5,  3, '2023-08-25', '2023-12-15', 'A',  4.0,  97.0),
(22,7,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  95.0),
(23,10, 3, '2023-08-25', '2023-12-15', 'B+', 3.3,  88.0),
(24,10, 3, '2023-08-25', '2023-12-15', 'B',  3.0,  85.0),
(24,14, 3, '2023-08-25', '2023-12-15', 'B+', 3.3,  87.0),
(26,1,  3, '2023-08-25', '2023-12-15', 'A+', 4.0, 100.0),
(27,5,  3, '2023-08-25', '2023-12-15', 'D',  1.0,  60.0),
(27,10, 3, '2023-08-25', '2023-12-15', 'F',  0.0,  48.0),
(28,14, 3, '2023-08-25', '2023-12-15', 'B-', 2.7,  83.0),
(29,10, 3, '2023-08-25', '2023-12-15', 'B',  3.0,  84.0),
(30,5,  3, '2023-08-25', '2023-12-15', 'A-', 3.7,  94.0),
-- Spring 2024 enrollments
(1, 2,  4, '2024-01-10', '2024-05-10', 'A',  4.0,  98.0),
(1, 6,  4, '2024-01-10', '2024-05-10', 'A-', 3.7,  96.0),
(3, 11, 4, '2024-01-10', '2024-05-10', 'B+', 3.3,  87.0),
(4, 2,  4, '2024-01-10', '2024-05-10', 'B+', 3.3,  90.0),
(4, 4,  4, '2024-01-10', '2024-05-10', 'A-', 3.7,  94.0),
(5, 6,  4, '2024-01-10', '2024-05-10', 'D+', 1.3,  65.0),
(7, 6,  4, '2024-01-10', '2024-05-10', 'A-', 3.7,  95.0),
(7, 8,  4, '2024-01-10', '2024-05-10', 'B+', 3.3,  89.0),
(8, 11, 4, '2024-01-10', '2024-05-10', 'B',  3.0,  85.0),
(9, 2,  4, '2024-01-10', '2024-05-10', 'C-', 1.7,  71.0),
(11,2,  4, '2024-01-10', '2024-05-10', 'A',  4.0,  99.0),
(11,6,  4, '2024-01-10', '2024-05-10', 'A+', 4.0, 100.0),
(12,6,  4, '2024-01-10', '2024-05-10', 'C+', 2.3,  76.0),
(13,11, 4, '2024-01-10', '2024-05-10', 'A-', 3.7,  95.0),
(16,6,  4, '2024-01-10', '2024-05-10', 'A-', 3.7,  94.0),
(17,18, 4, '2024-01-10', '2024-05-10', 'B',  3.0,  88.0),
(18,12, 4, '2024-01-10', '2024-05-10', 'A',  4.0,  97.0),
(19,2,  4, '2024-01-10', '2024-05-10', 'B',  3.0,  86.0),
(22,6,  4, '2024-01-10', '2024-05-10', 'A',  4.0,  98.0),
(26,2,  4, '2024-01-10', '2024-05-10', 'A+', 4.0, 100.0),
(28,15, 4, '2024-01-10', '2024-05-10', 'B-', 2.7,  82.0),
(29,11, 4, '2024-01-10', '2024-05-10', 'C+', 2.3,  77.0),
(30,6,  4, '2024-01-10', '2024-05-10', 'A',  4.0,  96.0),
-- Fall 2024 (current semester, in progress)
(1, 3,  5, '2024-08-22', NULL, NULL, NULL, 94.0),
(1, 9,  5, '2024-08-22', NULL, NULL, NULL, 97.0),
(4, 3,  5, '2024-08-22', NULL, NULL, NULL, 91.0),
(4, 9,  5, '2024-08-22', NULL, NULL, NULL, 88.0),
(7, 9,  5, '2024-08-22', NULL, NULL, NULL, 95.0),
(9, 1,  5, '2024-08-22', NULL, NULL, NULL, 73.0),
(11,3,  5, '2024-08-22', NULL, NULL, NULL, 100.0),
(11,13, 5, '2024-08-22', NULL, NULL, NULL, 99.0),
(13,13, 5, '2024-08-22', NULL, NULL, NULL, 96.0),
(16,9,  5, '2024-08-22', NULL, NULL, NULL, 92.0),
(18,13, 5, '2024-08-22', NULL, NULL, NULL, 98.0),
(22,9,  5, '2024-08-22', NULL, NULL, NULL, 97.0),
(26,3,  5, '2024-08-22', NULL, NULL, NULL, 100.0),
(26,16, 5, '2024-08-22', NULL, NULL, NULL, 100.0),
(28,16, 5, '2024-08-22', NULL, NULL, NULL, 84.0),
(30,9,  5, '2024-08-22', NULL, NULL, NULL, 95.0);


-- ============================================================
-- ASSIGNMENTS
-- ============================================================
CREATE TABLE raw_edu.assignments (
    assignment_id    SERIAL PRIMARY KEY,
    course_id        INT REFERENCES raw_edu.courses(course_id),
    semester_id      INT REFERENCES raw_edu.semesters(semester_id),
    assignment_name  VARCHAR(200) NOT NULL,
    assignment_type  VARCHAR(50),
    due_date         DATE,
    max_points       NUMERIC(6,2),
    weight_percentage NUMERIC(5,2),
    created_at       TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.assignments (course_id, semester_id, assignment_name, assignment_type, due_date, max_points, weight_percentage) VALUES
-- MATH101 Fall 2023
(1, 3, 'Chapter 1 Homework',     'Homework',     '2023-09-15', 100, 5.0),
(1, 3, 'Midterm Exam',           'Exam',         '2023-10-20', 100, 30.0),
(1, 3, 'Final Exam',             'Exam',         '2023-12-12', 100, 40.0),
-- SCI101 Fall 2023
(5, 3, 'Lab Report 1',           'Project',      '2023-09-22', 50,  10.0),
(5, 3, 'Genetics Quiz',          'Quiz',         '2023-10-05', 25,  5.0),
(5, 3, 'Midterm Exam',           'Exam',         '2023-10-19', 100, 30.0),
(5, 3, 'Final Exam',             'Exam',         '2023-12-13', 100, 40.0),
-- ENG101 Fall 2023
(10, 3, 'Essay 1',               'Homework',     '2023-09-20', 100, 10.0),
(10, 3, 'Midterm Essay',         'Exam',         '2023-10-18', 100, 25.0),
(10, 3, 'Research Paper',        'Project',      '2023-11-15', 100, 30.0),
(10, 3, 'Final Exam',            'Exam',         '2023-12-11', 100, 35.0),
-- HIST101 Fall 2023
(14, 3, 'Map Quiz',              'Quiz',         '2023-09-14', 25,  5.0),
(14, 3, 'Essay: Ancient Civ.',   'Homework',     '2023-10-06', 100, 15.0),
(14, 3, 'Midterm Exam',          'Exam',         '2023-10-20', 100, 30.0),
(14, 3, 'Final Exam',            'Exam',         '2023-12-12', 100, 40.0),
-- MATH201 Fall 2023
(2, 3, 'Problem Set 1',          'Homework',     '2023-09-18', 100, 5.0),
(2, 3, 'Midterm Exam',           'Exam',         '2023-10-23', 100, 35.0),
(2, 3, 'Final Exam',             'Exam',         '2023-12-14', 100, 45.0),
-- SCI102 Spring 2024
(6, 4, 'Lab Report 1',           'Project',      '2024-02-02', 50,  10.0),
(6, 4, 'Midterm Exam',           'Exam',         '2024-03-08', 100, 35.0),
(6, 4, 'Final Exam',             'Exam',         '2024-05-07', 100, 40.0),
-- MATH301 Spring 2024
(4, 4, 'Data Analysis Project',  'Project',      '2024-02-16', 100, 20.0),
(4, 4, 'Midterm Exam',           'Exam',         '2024-03-07', 100, 35.0),
(4, 4, 'Final Exam',             'Exam',         '2024-05-06', 100, 35.0),
-- ENG201 Spring 2024
(11, 4, 'Close Reading Essay',   'Homework',     '2024-02-09', 100, 15.0),
(11, 4, 'Midterm Exam',          'Exam',         '2024-03-06', 100, 30.0),
(11, 4, 'Term Paper',            'Project',      '2024-04-19', 100, 35.0),
(11, 4, 'Final Exam',            'Exam',         '2024-05-06', 100, 20.0),
-- HIST201 Spring 2024
(15, 4, 'Primary Source Essay',  'Homework',     '2024-02-14', 100, 15.0),
(15, 4, 'Midterm Exam',          'Exam',         '2024-03-11', 100, 35.0),
(15, 4, 'Final Exam',            'Exam',         '2024-05-08', 100, 40.0);


-- ============================================================
-- ASSIGNMENT SUBMISSIONS
-- ============================================================
CREATE TABLE raw_edu.assignment_submissions (
    submission_id   SERIAL PRIMARY KEY,
    assignment_id   INT REFERENCES raw_edu.assignments(assignment_id),
    student_id      INT REFERENCES raw_edu.students(student_id),
    submission_date DATE,
    score           NUMERIC(6,2),
    late_submission BOOLEAN DEFAULT FALSE,
    feedback        TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.assignment_submissions (assignment_id, student_id, submission_date, score, late_submission, feedback) VALUES
-- MATH101 Fall 2023 submissions (assignment_ids 1-3)
(1, 1, '2023-09-15', 96, FALSE, 'Excellent work'),
(1, 4, '2023-09-16', 88, TRUE,  'Good but late'),
(1, 9, '2023-09-15', 72, FALSE, 'Review factoring'),
(1, 11,'2023-09-15', 100,FALSE, 'Perfect'),
(1, 19,'2023-09-15', 80, FALSE, 'Solid effort'),
(1, 26,'2023-09-15', 99, FALSE, 'Outstanding'),
(2, 1, '2023-10-20', 94, FALSE, 'Strong performance'),
(2, 4, '2023-10-20', 90, FALSE, 'Good work'),
(2, 9, '2023-10-20', 68, FALSE, 'Needs improvement'),
(2, 11,'2023-10-20', 99, FALSE, 'Excellent'),
(2, 19,'2023-10-20', 82, FALSE, 'Passing'),
(2, 26,'2023-10-20', 98, FALSE, 'Outstanding'),
(3, 1, '2023-12-12', 97, FALSE, NULL),
(3, 4, '2023-12-12', 91, FALSE, NULL),
(3, 9, '2023-12-12', 65, FALSE, NULL),
(3, 11,'2023-12-12', 100,FALSE, NULL),
(3, 19,'2023-12-12', 78, FALSE, NULL),
(3, 26,'2023-12-12', 99, FALSE, NULL),
-- SCI101 Fall 2023 (assignment_ids 4-7)
(4, 1, '2023-09-22', 46, FALSE, 'Good lab technique'),
(4, 5, '2023-09-24', 30, TRUE,  'Incomplete sections'),
(4, 7, '2023-09-22', 48, FALSE, 'Excellent write-up'),
(4, 11,'2023-09-22', 49, FALSE, 'Near perfect'),
(4, 12,'2023-09-22', 35, FALSE, 'Missing analysis'),
(4, 16,'2023-09-22', 47, FALSE, 'Good'),
(4, 22,'2023-09-22', 50, FALSE, 'Perfect'),
(4, 30,'2023-09-22', 45, FALSE, 'Strong work'),
(5, 1, '2023-10-05', 24, FALSE, NULL),
(5, 7, '2023-10-05', 23, FALSE, NULL),
(5, 11,'2023-10-05', 25, FALSE, NULL),
(5, 16,'2023-10-05', 22, FALSE, NULL),
(5, 22,'2023-10-05', 25, FALSE, NULL),
(6, 1, '2023-10-19', 95, FALSE, NULL),
(6, 5, '2023-10-19', 52, FALSE, NULL),
(6, 7, '2023-10-19', 89, FALSE, NULL),
(6, 11,'2023-10-19', 97, FALSE, NULL),
(6, 12,'2023-10-19', 66, FALSE, NULL),
(6, 16,'2023-10-19', 91, FALSE, NULL),
(6, 22,'2023-10-19', 96, FALSE, NULL),
(6, 30,'2023-10-19', 92, FALSE, NULL),
(7, 1, '2023-12-13', 97, FALSE, NULL),
(7, 5, '2023-12-13', 58, FALSE, NULL),
(7, 7, '2023-12-13', 90, FALSE, NULL),
(7, 11,'2023-12-13', 99, FALSE, NULL),
(7, 12,'2023-12-13', 70, FALSE, NULL),
(7, 16,'2023-12-13', 93, FALSE, NULL),
(7, 22,'2023-12-13', 97, FALSE, NULL),
(7, 30,'2023-12-13', 94, FALSE, NULL),
-- ENG101 Fall 2023 (assignment_ids 8-11)
(8,  1, '2023-09-20', 95, FALSE, 'Great thesis'),
(8,  3, '2023-09-21', 82, TRUE,  'Strong but late'),
(8,  8, '2023-09-20', 88, FALSE, 'Good structure'),
(8,  18,'2023-09-20', 96, FALSE, 'Excellent'),
(8,  23,'2023-09-20', 85, FALSE, 'Solid essay'),
(8,  24,'2023-09-20', 83, FALSE, 'Good'),
(8,  29,'2023-09-20', 80, FALSE, 'Passing'),
(9,  1, '2023-10-18', 96, FALSE, NULL),
(9,  3, '2023-10-18', 85, FALSE, NULL),
(9,  8, '2023-10-18', 89, FALSE, NULL),
(9,  18,'2023-10-18', 97, FALSE, NULL),
(9,  23,'2023-10-18', 86, FALSE, NULL),
(9,  24,'2023-10-18', 84, FALSE, NULL),
(9,  29,'2023-10-18', 78, FALSE, NULL),
(10, 1, '2023-11-15', 97, FALSE, NULL),
(10, 3, '2023-11-16', 83, TRUE,  NULL),
(10, 8, '2023-11-15', 87, FALSE, NULL),
(10, 18,'2023-11-15', 98, FALSE, NULL),
(10, 23,'2023-11-15', 86, FALSE, NULL),
(10, 24,'2023-11-15', 85, FALSE, NULL),
(10, 29,'2023-11-15', 76, FALSE, NULL),
(11, 1, '2023-12-11', 98, FALSE, NULL),
(11, 3, '2023-12-11', 84, FALSE, NULL),
(11, 8, '2023-12-11', 86, FALSE, NULL),
(11, 18,'2023-12-11', 97, FALSE, NULL),
(11, 23,'2023-12-11', 83, FALSE, NULL),
(11, 24,'2023-12-11', 82, FALSE, NULL),
(11, 29,'2023-12-11', 75, FALSE, NULL);


-- ============================================================
-- FINANCIAL AID
-- ============================================================
CREATE TABLE raw_edu.financial_aid (
    aid_id          SERIAL PRIMARY KEY,
    student_id      INT REFERENCES raw_edu.students(student_id),
    aid_type        VARCHAR(100) NOT NULL,
    amount          NUMERIC(10,2),
    academic_year   VARCHAR(20),
    disbursement_date DATE,
    created_at      TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.financial_aid (student_id, aid_type, amount, academic_year, disbursement_date) VALUES
(1,  'Merit Scholarship',        5000,  '2023-2024', '2023-09-01'),
(1,  'Merit Scholarship',        5000,  '2024-2025', '2024-09-01'),
(3,  'Need-Based Grant',         4000,  '2023-2024', '2023-09-01'),
(3,  'Need-Based Grant',         4000,  '2024-2025', '2024-09-01'),
(5,  'Need-Based Grant',         6000,  '2023-2024', '2023-09-01'),
(7,  'Merit Scholarship',        4500,  '2023-2024', '2023-09-01'),
(7,  'Merit Scholarship',        4500,  '2024-2025', '2024-09-01'),
(8,  'Need-Based Grant',         3500,  '2023-2024', '2023-09-01'),
(9,  'Student Loan',             8000,  '2023-2024', '2023-09-01'),
(10, 'Student Loan',            10000,  '2022-2023', '2022-09-01'),
(11, 'Merit Scholarship',        7500,  '2023-2024', '2023-09-01'),
(11, 'Merit Scholarship',        7500,  '2024-2025', '2024-09-01'),
(12, 'Need-Based Grant',         5000,  '2023-2024', '2023-09-01'),
(13, 'Merit Scholarship',        4000,  '2022-2023', '2022-09-01'),
(13, 'Merit Scholarship',        4000,  '2023-2024', '2023-09-01'),
(15, 'Student Loan',             9000,  '2023-2024', '2023-09-01'),
(17, 'Need-Based Grant',         3000,  '2023-2024', '2023-09-01'),
(18, 'Merit Scholarship',        6000,  '2023-2024', '2023-09-01'),
(20, 'Work-Study Program',       2500,  '2023-2024', '2023-09-01'),
(22, 'Merit Scholarship',        5500,  '2023-2024', '2023-09-01'),
(22, 'Merit Scholarship',        5500,  '2024-2025', '2024-09-01'),
(26, 'Merit Scholarship',        8000,  '2023-2024', '2023-09-01'),
(26, 'Merit Scholarship',        8000,  '2024-2025', '2024-09-01'),
(29, 'Need-Based Grant',         4500,  '2023-2024', '2023-09-01'),
(30, 'Merit Scholarship',        5000,  '2023-2024', '2023-09-01');


-- ============================================================
-- TUITION PAYMENTS
-- ============================================================
CREATE TABLE raw_edu.tuition_payments (
    payment_id     SERIAL PRIMARY KEY,
    student_id     INT REFERENCES raw_edu.students(student_id),
    semester_id    INT REFERENCES raw_edu.semesters(semester_id),
    amount         NUMERIC(10,2),
    payment_date   DATE,
    payment_method VARCHAR(50),
    late_fee       NUMERIC(8,2) DEFAULT 0,
    created_at     TIMESTAMP DEFAULT NOW()
);

INSERT INTO raw_edu.tuition_payments (student_id, semester_id, amount, payment_date, payment_method, late_fee) VALUES
(1,  3, 6500, '2023-08-20', 'Bank Transfer',  0),
(1,  4, 6500, '2024-01-08', 'Bank Transfer',  0),
(1,  5, 6500, '2024-08-19', 'Bank Transfer',  0),
(2,  3, 6500, '2023-08-18', 'Credit Card',    0),
(3,  3, 6500, '2023-09-05', 'Check',        150),
(3,  4, 6500, '2024-01-22', 'Check',        150),
(4,  3, 6500, '2023-08-22', 'Bank Transfer',  0),
(4,  4, 6500, '2024-01-10', 'Bank Transfer',  0),
(4,  5, 6500, '2024-08-21', 'Bank Transfer',  0),
(5,  3, 6500, '2023-09-10', 'Cash',         150),
(5,  4, 6500, '2024-01-30', 'Cash',         150),
(6,  1, 6500, '2022-08-19', 'Bank Transfer',  0),
(7,  3, 6500, '2023-08-21', 'Credit Card',    0),
(7,  4, 6500, '2024-01-09', 'Credit Card',    0),
(7,  5, 6500, '2024-08-20', 'Credit Card',    0),
(8,  3, 6500, '2023-08-25', 'Check',          0),
(8,  4, 6500, '2024-01-12', 'Check',          0),
(9,  3, 6500, '2023-09-01', 'Bank Transfer',  0),
(9,  5, 6500, '2024-08-22', 'Bank Transfer',  0),
(10, 1, 6500, '2022-08-20', 'Student Loan',   0),
(11, 3, 6500, '2023-08-19', 'Credit Card',    0),
(11, 4, 6500, '2024-01-08', 'Credit Card',    0),
(11, 5, 6500, '2024-08-18', 'Credit Card',    0),
(12, 3, 6500, '2023-09-08', 'Bank Transfer', 150),
(13, 3, 6500, '2023-08-23', 'Bank Transfer',  0),
(13, 4, 6500, '2024-01-11', 'Bank Transfer',  0),
(15, 3, 6500, '2023-09-12', 'Student Loan', 150),
(16, 3, 6500, '2023-08-20', 'Credit Card',    0),
(17, 3, 6500, '2023-08-24', 'Check',          0),
(18, 3, 6500, '2023-08-19', 'Bank Transfer',  0),
(18, 4, 6500, '2024-01-08', 'Bank Transfer',  0),
(19, 3, 6500, '2023-08-22', 'Bank Transfer',  0),
(20, 3, 6500, '2023-09-15', 'Cash',         150),
(21, 1, 6500, '2022-08-21', 'Bank Transfer',  0),
(22, 3, 6500, '2023-08-20', 'Credit Card',    0),
(22, 4, 6500, '2024-01-09', 'Credit Card',    0),
(22, 5, 6500, '2024-08-19', 'Credit Card',    0),
(23, 3, 6500, '2023-08-23', 'Check',          0),
(24, 3, 6500, '2023-08-21', 'Bank Transfer',  0),
(25, 1, 6500, '2022-08-22', 'Student Loan',   0),
(26, 3, 6500, '2023-08-18', 'Bank Transfer',  0),
(26, 4, 6500, '2024-01-07', 'Bank Transfer',  0),
(26, 5, 6500, '2024-08-17', 'Bank Transfer',  0),
(27, 3, 6500, '2023-09-18', 'Cash',         150),
(28, 3, 6500, '2023-08-24', 'Check',          0),
(28, 4, 6500, '2024-01-13', 'Check',          0),
(28, 5, 6500, '2024-08-23', 'Check',          0),
(29, 3, 6500, '2023-08-22', 'Bank Transfer',  0),
(30, 3, 6500, '2023-08-20', 'Credit Card',    0),
(30, 4, 6500, '2024-01-09', 'Credit Card',    0);
