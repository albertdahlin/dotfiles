
syntax match Type /\w\+_t\s/
syntax match Operator "\v\+"
syntax match Operator "\V*"
syntax match Operator "\V="
syntax match Operator "\V-"
syntax match Operator "\V&"
syntax match Operator "\V/"
syntax match Operator "\V|"
syntax match Operator "\V<"
syntax match Operator "\V>"
syntax match Constant /[A-Z_]\{4,}/
"match Operator "\v\/"
" match Constant /[()\[\]]/
syntax keyword Type GLuint GLint GLFWwindow GLfloat GLsizei GLchar GLenum
