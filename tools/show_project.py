from projects.models import Project

# 查詢所有項目
projects = Project.objects.all()
for project in projects:
    print(project.id, project.name)
