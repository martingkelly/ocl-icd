=begin
Copyright (c) 2012, Brice Videau <brice.videau@imag.fr>
All rights reserved.
      
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    
1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
        
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
=end

require 'yaml'

module IcdGenerator
  $api_entries = {}
  $api_entries_array = []
  $cl_objects = ["platform_id", "device_id", "context", "command_queue", "mem", "program", "kernel", "event", "sampler"]
  $known_entries= { 1 => "clGetPlatformInfo", 0 => "clGetPlatformIDs" }
  $forbidden_funcs = ["clGetPlatformInfo", "clUnloadCompiler", "clGetExtensionFunctionAddress","clGetPlatformIDs" ]
  $header_files = ["/usr/include/CL/cl.h", "/usr/include/CL/cl_gl.h", "/usr/include/CL/cl_ext.h", "/usr/include/CL/cl_gl_ext.h"]
#  $header_files = ["./cl.h", "./cl_gl.h", "./cl_ext.h", "./cl_gl_ext.h"]
  $buff=20
  $license = <<EOF
Copyright (c) 2012, Brice Videau <brice.videau@imag.fr>
All rights reserved.
      
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    
1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
        
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
EOF

  def self.parse_headers
    api_entries = []
    $header_files.each{ |fname|
      f = File::open(fname)
      doc = f.read
      api_entries += doc.scan(/CL_API_ENTRY.*?;/m).reject {|item| item.match("KHR")}
      f.close
    }
    api_entries.each{ |entry|
#      puts entry
      begin 
        entry_name = entry.match(/CL_API_CALL(.*?)\(/m)[1].strip
        next if entry_name.match('\*')
        next if entry_name.match("INTEL")
        next if entry_name.match("APPLE")
        $api_entries[entry_name] = entry
       
      rescue
        entry_name = entry.match(/(\S*?)\(/m)[1].strip
        next if entry_name.match('\*')
        next if entry_name.match("INTEL")
        next if entry_name.match("APPLE")
        $api_entries[entry_name] = entry
      end
    }
#    $api_entries.each{ |key, value|
#      puts "#{key}: #{value}"
#    }
  end

  def self.include_headers
    headers =""
    $header_files.each { |h|
      headers += "#include \"#{h}\"\n"
    }
    return headers
  end
  def self.generate_ocl_icd_header
    ocl_icd_header = "/**\n#{$license}\n*/"
    ocl_icd_header +=  "#include <CL/opencl.h>\n"
    ocl_icd_header += self.include_headers
    ocl_icd_header +=  "struct _cl_icd_dispatch {\n"
    $api_entries.each_value { |entry|
      ocl_icd_header += entry.sub(/CL_API_CALL(.*?)\(/m,'(CL_API_CALL*\1)(').gsub("\r","") + "\n"
    }
    $buff.times {|i|
      ocl_icd_header += "void (* dummyFunc#{i})(void) ;\n"
    }
    return ocl_icd_header += "};\n"
  end

  def self.generate_ocl_icd_header_final
    ocl_icd_header = "/**\n#{$license}\n*/"
    ocl_icd_header += "#define CL_USE_DEPRECATED_OPENCL_1_0_APIS\n"
    ocl_icd_header += "#define CL_USE_DEPRECATED_OPENCL_1_1_APIS\n"
    ocl_icd_header += "#include <CL/opencl.h>\n"
    ocl_icd_header += self.include_headers
    ocl_icd_header += "struct _cl_icd_dispatch {\n"
    $api_entries_array.each { |entry|
      ocl_icd_header += entry.sub(/CL_API_CALL(.*?)\(/m,'(CL_API_CALL*\1)(').gsub("\r","") + "\n"
    }
    ocl_icd_header += "};\n"
    ocl_icd_header += "extern struct _cl_icd_dispatch master_dispatch;\n"
    $cl_objects.each { |o|
      ocl_icd_header += "struct _cl_#{o} { struct _cl_icd_dispatch *dispatch; };\n"
    }
    return ocl_icd_header
  end

  def self.generate_ocl_icd_source
    ocl_icd_source = "/**\n#{$license}\n*/"
    ocl_icd_source += "#include \"ocl_icd.h\"\n"
    ocl_icd_source += "struct _cl_icd_dispatch master_dispatch = {\n"
    ($api_entries.length+$buff-1).times { |i|
      if( $known_entries[i] ) then 
        ocl_icd_source += "  #{$known_entries[i]},\n"
      else
        ocl_icd_source += "  (void *) NULL,\n"
      end
    }
    if( $known_entries[$api_entries.length+$buff-1] ) then
      ocl_icd_source += "  #{$known_entries[i]}\n"
    else
      ocl_icd_source += "  (void *) NULL\n"
    end
    ocl_icd_source += "};\n"
    ocl_icd_source += <<EOF

CL_API_ENTRY cl_int CL_API_CALL clIcdGetPlatformIDsKHR(  
             cl_uint num_entries, 
             cl_platform_id *platforms,
             cl_uint *num_platforms) {
  if( platforms == NULL && num_platforms == NULL )
    return CL_INVALID_VALUE;
  if( num_entries == 0 && platforms != NULL )
    return CL_INVALID_VALUE;
#error You have to fill the commented lines with corresponding variables from your library
//  if( your_number_of_platforms == 0)
//    return CL_PLATFORM_NOT_FOUND_KHR;
//  if( num_platforms != NULL )
//    *num_platforms = your_number_of_platforms;
  if( platforms != NULL ) {
    cl_uint i;
//    for( i=0; i<(your_number_of_platforms<num_entries?your_number_of_platforms:num_entries); i++)
//      platforms[i] = &your_platforms[i];
  }
  return CL_SUCCESS;
}

CL_API_ENTRY void * CL_API_CALL clGetExtensionFunctionAddress(
             const char *   func_name) CL_API_SUFFIX__VERSION_1_0 {
#error You have to fill this function with your extensions of incorporate these lines in your version
  if( func_name != NULL &&  strcmp("clIcdGetPlatformIDsKHR", func_name) == 0 )
    return (void *)clIcdGetPlatformIDsKHR;
  return NULL;
}
CL_API_ENTRY cl_int CL_API_CALL clGetPlatformInfo(
             cl_platform_id   platform, 
             cl_platform_info param_name,
             size_t           param_value_size, 
             void *           param_value,
             size_t *         param_value_size_ret) CL_API_SUFFIX__VERSION_1_0 {
#error You ahve to fill this function with your information or assert that your version responds to CL_PLATFORM_ICD_SUFFIX_KHR
//  char cl_platform_profile[] = "FULL_PROFILE";
//  char cl_platform_version[] = "OpenCL 1.1";
//  char cl_platform_name[] = "DummyCL";
//  char cl_platform_vendor[] = "LIG";
//  char cl_platform_extensions[] = "cl_khr_icd";
//  char cl_platform_icd_suffix_khr[] = "DUMMY";
  size_t size_string;
  char * string_p;
  if( platform != NULL ) {
    int found = 0;
    int i;
    for(i=0; i<num_master_platforms; i++) {
      if( platform == &master_platforms[i] )
        found = 1;
    }
    if(!found)
      return CL_INVALID_PLATFORM;
  }
  switch ( param_name ) {
    case CL_PLATFORM_PROFILE:
      string_p = cl_platform_profile;
      size_string = sizeof(cl_platform_profile);
      break;
    case CL_PLATFORM_VERSION:
      string_p = cl_platform_version;
      size_string = sizeof(cl_platform_version);
      break;
    case CL_PLATFORM_NAME:
      string_p = cl_platform_name;
      size_string = sizeof(cl_platform_name);
      break;
    case CL_PLATFORM_VENDOR:
      string_p = cl_platform_vendor;
      size_string = sizeof(cl_platform_vendor);
      break;
    case CL_PLATFORM_EXTENSIONS:
      string_p = cl_platform_extensions;
      size_string = sizeof(cl_platform_extensions);
      break;
    case CL_PLATFORM_ICD_SUFFIX_KHR:
      string_p = cl_platform_icd_suffix_khr;
      size_string = sizeof(cl_platform_icd_suffix_khr);
      break;
    default:
      return CL_INVALID_VALUE;
      break;
  }
  if( param_value != NULL ) {
    if( size_string > param_value_size )
      return CL_INVALID_VALUE;
    memcpy(param_value, string_p, size_string);
  }
  if( param_value_size_ret != NULL )
    *param_value_size_ret = size_string;
  return CL_SUCCESS;
}
EOF
    return ocl_icd_source
  end
 
  def self.generate_ocl_icd_dummy_header
    ocl_icd_dummy_header = "/**\n#{$license}\n*/"
    ocl_icd_dummy_header += "#include <CL/opencl.h>\n"
    ocl_icd_dummy_header += "#include \"ocl_icd.h\"\n"
    ($api_entries.length+$buff).times { |i|
      ocl_icd_dummy_header += "void dummyFunc#{i}(void);\n"
    }
    ocl_icd_dummy_header += "struct _cl_icd_dispatch master_dispatch = {\n"
    ($api_entries.length+$buff-1).times { |i|
      if( $known_entries[i] ) then 
        ocl_icd_dummy_header += "  (void *)& #{$known_entries[i]},\n"
      else
        ocl_icd_dummy_header += "  (void *)& dummyFunc#{i},\n"
      end
    }
    if( $known_entries[$api_entries.length+$buff-1] ) then
      cl_icd_dummy_header += "  (void *)& #{$known_entries[$api_entries.length+$buff-1]}\n"
    else
      ocl_icd_dummy_header += "  (void *)& dummyFunc#{$api_entries.length+$buff-1}\n"
    end
    ocl_icd_dummy_header += "};\n"
    $cl_objects.each { |o|
      ocl_icd_dummy_header += "struct _cl_#{o} { struct _cl_icd_dispatch *dispatch; };\n"
      ocl_icd_dummy_header += "struct _cl_#{o} master_#{o} = { &master_dispatch };\n"
    }
    return ocl_icd_dummy_header
  end
 
  def self.generate_ocl_icd_lib_source
    forbidden_funcs = $forbidden_funcs[2..-1]
    ocl_icd_lib_source = "/**\n#{$license}\n*/"
    ocl_icd_lib_source += "#include \"ocl_icd.h\"\n"
    ocl_icd_lib_source += ""
    $api_entries.each { |func_name, entry|
      next if forbidden_funcs.include?(func_name)
      clean_entry = entry.sub(/(.*\)).*/m,'\1').gsub("/*","").gsub("*/","").gsub("\r","") + "{\n"
      parameters = clean_entry.match(/\(.*\)/m)[0][1..-2]
      parameters.gsub!(/\[.*?\]/,"")
      parameters.sub!(/\(.*?\*\s*(.*?)\)\s*\(.*?\)/,'\1')
      ocl_icd_lib_source += clean_entry.gsub(/\[.*?\]/,"")
      if func_name == "clCreateContext" then
        ocl_icd_lib_source += <<EOF
  cl_uint i=0;
  if( properties != NULL){
    while( properties[i] != 0 ) {
      if( properties[i] == CL_CONTEXT_PLATFORM )
        return ((struct _cl_platform_id *) properties[i+1])->dispatch->clCreateContext(properties, num_devices, devices, pfn_notify, user_data, errcode_ret);
      i += 2;
    }
  }
  if(devices == NULL || num_devices == 0) {
    *errcode_ret = CL_INVALID_VALUE;
    return NULL;
  }
  return ((struct _cl_device_id *)devices[0])->dispatch->clCreateContext(properties, num_devices, devices, pfn_notify, user_data, errcode_ret);
EOF
      elsif func_name == "clCreateContextFromType" then
        ocl_icd_lib_source += <<EOF
  cl_uint i=0;
  if( properties != NULL){
    while( properties[i] != 0 ) {
      if( properties[i] == CL_CONTEXT_PLATFORM )
        return ((struct _cl_platform_id *) properties[i+1])->dispatch->clCreateContextFromType(properties, device_type, pfn_notify, user_data, errcode_ret);
      i += 2;
    }
  }
  *errcode_ret = CL_INVALID_PLATFORM;
  return NULL;
EOF
      elsif func_name == "clWaitForEvents" then
        ocl_icd_lib_source += <<EOF
  if( num_events == 0 || event_list == NULL )
    return CL_INVALID_VALUE;
  return ((struct _cl_event *)event_list[0])->dispatch->clWaitForEvents(num_events, event_list);
EOF
      elsif func_name == "clUnloadCompiler" then
        ocl_icd_lib_source += <<EOF
  return CL_SUCCESS;
EOF
      else
        first_parameter = parameters.match(/.*?\,/m)
        if not first_parameter then
          first_parameter =  parameters.match(/.*/m)[0]
        else
          first_parameter = first_parameter[0][0..-2]
        end
        fps = first_parameter.split
        ocl_icd_lib_source += "return ((struct _#{fps[0]} *)#{fps[1]})->dispatch->#{func_name}("
        ps = parameters.split(",")
        ps = ps.collect { |p|
          p = p.split
          p = p[-1].gsub("*","")
        }
        ocl_icd_lib_source += ps.join(", ")
        ocl_icd_lib_source += ");\n"
      end
      ocl_icd_lib_source += "}\n\n"
    }

    return ocl_icd_lib_source;
  end
  
  def self.generate_ocl_icd_dummy_source
    ocl_icd_dummy_source = "/**\n#{$license}\n*/"
    ocl_icd_dummy_source += "#include \"ocl_icd_dummy.h\"\n"
    ocl_icd_dummy_source += "#include <stdio.h>\n"
    ocl_icd_dummy_source += "#include <string.h>\n"
    ocl_icd_dummy_source += <<EOF
#define NUM_PLATFORMS 1
#define DEBUG 0
cl_uint const num_master_platforms = NUM_PLATFORMS;
struct _cl_platform_id master_platforms[NUM_PLATFORMS] = { {&master_dispatch} };
CL_API_ENTRY cl_int CL_API_CALL clGetPlatformIDs(  
             cl_uint num_entries, 
             cl_platform_id *platforms,
             cl_uint *num_platforms) {
  return clIcdGetPlatformIDsKHR(num_entries, platforms, num_platforms);
}
CL_API_ENTRY cl_int CL_API_CALL clIcdGetPlatformIDsKHR(  
             cl_uint num_entries, 
             cl_platform_id *platforms,
             cl_uint *num_platforms) {
#if DEBUG
  printf("In clIcdGetPlatformIDsKHR...\\n");
#endif
  if( platforms == NULL && num_platforms == NULL )
    return CL_INVALID_VALUE;
  if( num_entries == 0 && platforms != NULL )
    return CL_INVALID_VALUE;
  if( num_master_platforms == 0)
    return CL_PLATFORM_NOT_FOUND_KHR;
  if( num_platforms != NULL ){
#if DEBUG
  printf("  asked num_platforms\\n");
#endif
    *num_platforms = num_master_platforms; }
  if( platforms != NULL ) {
#if DEBUG
  printf("  asked platforms\\n");
#endif
    cl_uint i;
    for( i=0; i<(num_master_platforms<num_entries?num_master_platforms:num_entries); i++)
      platforms[i] = &master_platforms[i];
  }
  return CL_SUCCESS;
}

/*CL_API_ENTRY void * CL_API_CALL clGetExtensionFunctionAddressForPlatform(
             cl_platform_id platform,
             const char *   func_name) CL_API_SUFFIX__VERSION_1_2 {
}*/

CL_API_ENTRY void * CL_API_CALL clGetExtensionFunctionAddress(
             const char *   func_name) CL_API_SUFFIX__VERSION_1_0 {
#if DEBUG
  printf("In clGetExtensionFunctionAddress... asked %s\\n", func_name);
#endif
  if( func_name != NULL &&  strcmp("clIcdGetPlatformIDsKHR", func_name) == 0 )
    return (void *)clIcdGetPlatformIDsKHR;
  return NULL;
}
CL_API_ENTRY cl_int CL_API_CALL clGetPlatformInfo(
             cl_platform_id   platform, 
             cl_platform_info param_name,
             size_t           param_value_size, 
             void *           param_value,
             size_t *         param_value_size_ret) CL_API_SUFFIX__VERSION_1_0 {
#if DEBUG
  printf("In clGetPlatformInfo...\\n");
#endif

  char cl_platform_profile[] = "FULL_PROFILE";
  char cl_platform_version[] = "OpenCL 1.1";
  char cl_platform_name[] = "DummyCL";
  char cl_platform_vendor[] = "LIG";
  char cl_platform_extensions[] = "cl_khr_icd";
  char cl_platform_icd_suffix_khr[] = "dummy";
  size_t size_string;
  char * string_p;
  if( platform != NULL ) {
    int found = 0;
    int i;
    for(i=0; i<num_master_platforms; i++) {
      if( platform == &master_platforms[i] )
        found = 1;
    }
    if(!found)
      return CL_INVALID_PLATFORM;
  }
  switch ( param_name ) {
    case CL_PLATFORM_PROFILE:
      string_p = cl_platform_profile;
      size_string = sizeof(cl_platform_profile);
      break;
    case CL_PLATFORM_VERSION:
      string_p = cl_platform_version;
      size_string = sizeof(cl_platform_version);
      break;
    case CL_PLATFORM_NAME:
      string_p = cl_platform_name;
      size_string = sizeof(cl_platform_name);
      break;
    case CL_PLATFORM_VENDOR:
      string_p = cl_platform_vendor;
      size_string = sizeof(cl_platform_vendor);
      break;
    case CL_PLATFORM_EXTENSIONS:
      string_p = cl_platform_extensions;
      size_string = sizeof(cl_platform_extensions);
      break;
    case CL_PLATFORM_ICD_SUFFIX_KHR:
      string_p = cl_platform_icd_suffix_khr;
      size_string = sizeof(cl_platform_icd_suffix_khr);
      break;
    default:
      return CL_INVALID_VALUE;
      break;
  }
  if( param_value != NULL ) {
    if( size_string > param_value_size )
      return CL_INVALID_VALUE;
    memcpy(param_value, string_p, size_string);
  }
  if( param_value_size_ret != NULL )
    *param_value_size_ret = size_string;
  return CL_SUCCESS;
}
EOF
    (0...$api_entries.length+$buff).each { |i|
      ocl_icd_dummy_source += "void dummyFunc#{i}(void){ printf(\"#{i}  : \"); fflush(NULL); }\n"
    }
    return ocl_icd_dummy_source
  end
  
  def self.generate_ocl_icd_dummy_test_source
    ocl_icd_dummy_test = "/**\n#{$license}\n*/"
    ocl_icd_dummy_test += "#include <stdlib.h>\n"
    ocl_icd_dummy_test += "#define CL_USE_DEPRECATED_OPENCL_1_0_APIS\n"
    ocl_icd_dummy_test += "#define CL_USE_DEPRECATED_OPENCL_1_1_APIS\n"
    ocl_icd_dummy_test += "#include <CL/opencl.h>\n"
    ocl_icd_dummy_test += self.include_headers
    ocl_icd_dummy_test += "#include <stdio.h>\n"
    ocl_icd_dummy_test += "#include <string.h>\n"
    ocl_icd_dummy_test += "int main(void) {\n"
    ocl_icd_dummy_test += <<EOF
  int i;
  cl_uint num_platforms;
  clGetPlatformIDs( 0, NULL, &num_platforms);
  cl_platform_id *platforms = malloc(sizeof(cl_platform_id) * num_platforms);
  clGetPlatformIDs(num_platforms, platforms, NULL);
#ifdef DEBUG
  fprintf(stderr, "Found %d platforms.\\n", num_platforms);
#endif
  cl_platform_id chosen_platform=NULL;
  CL_API_ENTRY cl_int (CL_API_CALL* oclFuncPtr)(cl_platform_id platform);
  typedef CL_API_ENTRY cl_int (CL_API_CALL* oclFuncPtr_fn)(cl_platform_id platform);

   for(i=0; i<num_platforms; i++){
     char *platform_vendor;
     size_t param_value_size_ret;

     clGetPlatformInfo(platforms[i], CL_PLATFORM_VENDOR, 0, NULL, &param_value_size_ret );
     platform_vendor = (char *)malloc(param_value_size_ret);
     clGetPlatformInfo(platforms[i], CL_PLATFORM_VENDOR, param_value_size_ret, platform_vendor, NULL );

#ifdef DEBUG
     fprintf(stderr, "%s\\n",platform_vendor);
#endif
     if( strcmp(platform_vendor, "LIG") == 0)
       chosen_platform = platforms[i];
     free(platform_vendor);
  }
  if( chosen_platform == NULL ) {
    fprintf(stderr,"Error LIG platform not found!\\n");
    return -1;
  }

  cl_context_properties properties[] = { CL_CONTEXT_PLATFORM, (cl_context_properties)chosen_platform, 0 };
  printf("---\\n");
EOF
    $api_entries.each_key { |func_name|
       next if $forbidden_funcs.include?(func_name)
       ocl_icd_dummy_test += "  fflush(NULL);\n"
       if func_name == "clCreateContext" then
         ocl_icd_dummy_test += "  #{func_name}(properties,1,(cl_device_id*)&chosen_platform,NULL,NULL,NULL);\n"
       elsif func_name == "clCreateContextFromType" then
         ocl_icd_dummy_test += "  #{func_name}(properties,CL_DEVICE_TYPE_CPU,NULL,NULL,NULL);\n"
       elsif func_name == "clWaitForEvents" then
         ocl_icd_dummy_test += "  #{func_name}(1,(cl_event*)&chosen_platform);\n"
       else
         ocl_icd_dummy_test += "  oclFuncPtr = (oclFuncPtr_fn)" + func_name + ";\n"
         ocl_icd_dummy_test += "  oclFuncPtr(chosen_platform);\n"
       end
       ocl_icd_dummy_test += "  printf(\"%s\\n\", \"#{func_name}\");"
    }
    return ocl_icd_dummy_test += "  return 0;\n}\n"
  end

  def self.generate_sources
    parse_headers
    File.open('ocl_icd.h','w') { |f|
      f.puts generate_ocl_icd_header
    }
    File.open('ocl_icd_dummy.h','w') { |f|
      f.puts generate_ocl_icd_dummy_header
    }
    File.open('ocl_icd_dummy.c','w') { |f|
      f.puts generate_ocl_icd_dummy_source
    }
    File.open('ocl_icd_dummy_test.c','w') { |f|
      f.puts generate_ocl_icd_dummy_test_source
    }
  end

  def self.savedb
    api_db = {}
    begin
      File::open("ocl_interface.yaml","r") { |f|
        api_db = YAML::load(f.read)
#        puts api_db.inspect
      }
    rescue
      api_db = {}
    end
    $known_entries.each_key {|i|
      next if api_db[i]
      api_db[i] = $api_entries[$known_entries[i]].gsub("\r","")
    }
    File::open("ocl_interface.yaml","w") { |f|
      f.write($license.gsub(/^/,"# "))
      f.write(YAML::dump(api_db))
    }
  end

  def self.finalize
    parse_headers
    doc = YAML::load(`./ocl_icd_dummy_test`)
    $known_entries.merge!(doc)
    self.savedb
    unknown=0
    $api_entries_array = []
    ($known_entries.length+$buff).times { |i|
      #puts $known_entries[i]
      if $known_entries[i] then
        $api_entries_array.push( $api_entries[$known_entries[i]] )
      else
        $api_entries_array.push( "CL_API_ENTRY cl_int CL_API_CALL clUnknown#{unknown}(void);" )
        unknown += 1
      end
    }
    File.open('ocl_icd.h','w') { |f|
      f.puts generate_ocl_icd_header_final
    }
    File.open('ocl_icd_bindings.c','w') { |f|
      f.puts generate_ocl_icd_source
    }
    File.open('ocl_icd_lib.c','w') { |f|
      f.puts generate_ocl_icd_lib_source
    }
  end
  
  def self.generate_from_database
    doc={}
    File::open('./ocl_interface.yaml') { |f|
      doc = YAML:: load(f.read)
    }
    $known_entries = {}
    $api_entries = {}
    entry_name = ""
    doc.each { |key, value|
      begin
        entry_name = value.match(/CL_API_CALL(.*?)\(/m)[1].strip
      rescue
        entry_name = value.match(/(\S*?)\(/m)[1].strip
      end
      $known_entries[key] = entry_name
      $api_entries[entry_name] = value
    }
    $api_entries_array = []
    unknown=0
    ($known_entries.length+$buff).times { |i|
      #puts $known_entries[i]
      if $known_entries[i] then
        $api_entries_array.push( $api_entries[$known_entries[i]] )
      else
        $api_entries_array.push( "CL_API_ENTRY cl_int CL_API_CALL clUnknown#{unknown}(void);" )
        unknown += 1
      end
    }
    File.open('ocl_icd.h','w') { |f|
      f.puts generate_ocl_icd_header_final
    }
    File.open('ocl_icd_bindings.c','w') { |f|
      f.puts generate_ocl_icd_source
    }
    File.open('ocl_icd_lib.c','w') { |f|
      f.puts generate_ocl_icd_lib_source
    }
  end
end

if ARGV[0] == "--generate"
  IcdGenerator.generate_sources
elsif ARGV[0] == "--finalize"
  IcdGenerator.finalize
elsif ARGV[0] == "--database"
  IcdGenerator.generate_from_database
else
  raise "Argument must be one of --generate or --finalize" 
end
