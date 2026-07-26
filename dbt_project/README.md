# DbtEducationalDataProject

A comprehensive educational data analytics project built with dbt, featuring 45 interconnected models that analyze student performance, faculty effectiveness, program effectiveness, and institutional operations.

## Project Overview

This project models a complete educational institution's data ecosystem, featuring comprehensive dbt transformations that demonstrate the full power of modern data engineering.

### Here's what makes dbt powerful:

- **Lineage Tracking** - Every transformation is fully documented — you can trace the entire data flow from the original source all the way to the dashboard or application that consumes the final (gold) data.

- **Testing** - Built-in data quality checks ensure reliability. Tests in dbt are defined separately, allowing you to validate any SQL logic. If a test fails, dbt automatically prevents downstream models from building, protecting your pipeline integrity.

- **Modularity** - Reusable models and macros promote the DRY (Don't Repeat Yourself) principle — you write logic once and reuse it across projects. This brings the power of functional programming concepts into data transformation.

- **Documentation** - dbt automatically generates rich documentation for your entire project — including models, lineage, and tests. As you can see here, all of this was created automatically by dbt, not manually coded.

### The Limitations Wall

While dbt docs give us this lovely visual, they can't answer the complex questions our education clients ask daily. Let me give you some real examples:

🔴 **Blast Radius Analysis:**
"What's the complete blast radius if I need to rebuild the stg_students table? Show me all downstream models that would be affected, including their materialization types."

🔗 **Dependency Complexity:**
"Which models create the longest dependency chains in our project, and what's the maximum depth of any single lineage path from source to final mart?"

💰 **Resource Optimization:**
"Which source tables are contributing to the most 'table' materializations downstream? I want to optimize our warehouse storage costs."

⚙️ **Job Orchestration:**
"If I wanted to create 5 separate dbt jobs that could run in parallel, how would you group our models to minimize cross-job dependencies?"

This project models a complete educational institution's data ecosystem, including:

### Data Sources
- **Students**: Enrollment, demographics, academic standing
- **Faculty**: Employment, teaching assignments, compensation
- **Courses**: Catalog, prerequisites, difficulty levels
- **Departments**: Budgets, organization structure
- **Enrollments**: Course registrations and performance
- **Assignments**: Coursework and submission tracking
- **Activities**: Extracurricular participation and attendance records
- **Academic Calendar**: Quarters and schedules

### Model Architecture

#### Staging Layer (12 models)
Data cleaning and standardization:
- `stg_students`, `stg_faculty`, `stg_courses`, `stg_departments`
- `stg_enrollments`, `stg_quarters`, `stg_class_sessions`
- `stg_assignments`, `stg_assignment_submissions`
- `stg_extracurricular_activities`, `stg_attendance_records`

#### Intermediate Layer (12 models)
Complex business logic and relationships:
- `int_student_enrollment_history`: Student academic progression
- `int_course_performance_metrics`: Course success analytics
- `int_faculty_teaching_load`: Teaching workload analysis
- `int_department_analytics`: Departmental performance
- `int_assignment_performance`: Assignment effectiveness
- `int_student_at_risk_indicators`: Early warning system
- `int_course_prerequisite_chains`: Curriculum sequencing
- `int_grade_inflation_analysis`: Grading trends
- `int_faculty_student_interactions`: Teaching effectiveness
- `int_academic_collaboration_networks`: Student connections
- `int_student_success_predictors`: Retention modeling
- `int_resource_utilization_analysis`: Operational efficiency
- `int_curriculum_flow_analysis`: Learning pathway optimization

#### Marts Layer (21 models)

**Core Business Models (9):**
- `student_academic_summary`: Comprehensive student profiles
- `course_catalog_enhanced`: Enhanced course information
- `faculty_performance_dashboard`: Teaching effectiveness metrics
- `department_efficiency_report`: Operational performance
- `graduation_pathway_analysis`: Degree completion tracking
- `institutional_effectiveness_dashboard`: Executive metrics
- `academic_early_warning_system`: Student intervention alerts
- `institutional_kpi_dashboard`: Key performance indicators

**Academic Analytics (7):**
- `student_retention_analysis`: Exit and transfer-out prevention
- `course_success_predictors`: Academic outcome modeling
- `quarter_enrollment_trends`: Enrollment patterns
- `instructor_effectiveness_scorecard`: Teaching quality
- `assignment_workload_analysis`: Course load optimization
- `learning_outcome_assessment`: Educational effectiveness
- `course_difficulty_calibration`: Curriculum standards
- `competitive_program_benchmarking`: Program comparison

**Programs & Operations (5):**
- `student_activity_profile`: Student extracurricular and attendance summary
- `attendance_analytics`: Attendance trend and intervention analysis
- `extracurricular_impact_analysis`: Activity participation impact on academics
- `program_participation_analysis`: Program engagement by department and quarter
- `resource_allocation_analysis`: Department resource efficiency and optimization

### Key Features

#### Complex Dependencies
- Models reference multiple upstream sources
- Layered transformations with intermediate calculations
- Cross-functional analysis spanning academic and financial domains

#### Advanced Analytics
- Predictive modeling for student success
- Network analysis for student collaboration
- Time-series analysis for trends
- Risk scoring and early warning systems

#### Business Intelligence
- Executive dashboards and KPI tracking
- Comparative benchmarking
- Resource optimization recommendations
- Financial performance analysis

### Macros and Utilities
- `grade_point_calculator`: Grade to GPA conversion
- `academic_year_from_date`: Academic year calculation
- `calculate_gpa`: Weighted GPA computation
- `test_referential_integrity`: Data quality testing

### Seeds and Reference Data
- `grade_scale_reference`: Grading standards
- `quarter_calendar`: Academic calendar
- `academic_calendar_holidays`: Holiday tracking

## Getting Started

### Local Development

1. **Setup Profiles**:
   ```bash
   cp profiles.yml ~/.dbt/profiles.yml
   ```

2. **Install Dependencies**:
   ```bash
   dbt deps
   ```

3. **Run Models**:
   ```bash
   dbt run
   ```

4. **Test Data Quality**:
   ```bash
   dbt test
   ```

5. **Generate Documentation**:
   ```bash
   dbt docs generate
   dbt docs serve
   ```

### Docker Setup

For a containerized environment with dbt docs:

1. **Start the Educational dbt Docs Server**:
   ```bash
   just educational-dbt-docs
   ```

2. **Access the Documentation**:
   Open your browser to [http://localhost:8502](http://localhost:8502)

3. **Stop the Server**:
   ```bash
   just educational-dbt-docs-down
   ```

The Docker setup includes:
- Uses existing PostgreSQL database from main docker-compose
- dbt docs server (port 8502)
- Automatic model compilation and documentation generation
- All dependencies and setup handled automatically

**Note**: Make sure the main postgres service is running first:
```bash
docker compose -f docker-compose.postgres.yml up -d
```

## Model Dependencies

The project follows a strict dependency hierarchy:
- Staging → Intermediate → Marts
- Complex cross-model references in intermediate layer
- Business-ready outputs in marts layer

## Use Cases

### Academic Leadership
- Monitor student retention and success rates
- Evaluate faculty teaching effectiveness
- Optimize course offerings and scheduling
- Track graduation pathways and bottlenecks

### Financial Management
- Analyze tuition revenue and collection
- Optimize financial aid allocation
- Monitor departmental budget performance
- Forecast enrollment and revenue

### Student Services
- Early identification of at-risk students
- Academic planning and course sequencing
- Financial counseling and aid optimization
- Collaborative learning network analysis

### Institutional Research
- Comparative program benchmarking
- Curriculum effectiveness assessment
- Resource utilization optimization
- Strategic planning and forecasting

## Data Quality

The project includes comprehensive data quality tests:
- Referential integrity checks
- Business rule validation
- Data freshness monitoring
- Anomaly detection

## Technology Stack

- **dbt**: Data transformation and modeling
- **PostgreSQL**: Data warehouse
- **SQL**: Core transformation logic
- **Jinja**: Templating and macros