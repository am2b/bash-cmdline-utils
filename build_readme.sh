#!/usr/bin/env bash

#=tools
#@在项目根目录运行以构建README.md

case $(uname -s | tr '[:upper:]' '[:lower:]') in
    'darwin')
        os='mac';;
    'linux')
        os='linux';;
    *)
        os='unknown:'$(uname -s);;
esac

function do_sed()
{
    if [[ "${os}" == 'mac' ]]; then
        gsed "$@"
    elif [[ "${os}" == 'linux' ]]; then
        sed "$@"
    fi
}

readme_name=README.md

#设置README.md的路径
readme_path=$(pwd)

#查看是否已经存在README.md文件
readme_already_exists=0
if [ -f "${readme_path}"/"${readme_name}" ]; then readme_already_exists=1; fi

#设置项目根目录的路径,来作为起始扫描点
project_root_path=$(pwd)

#查看在项目的根目录是否存在.git文件夹,如果不存在的话,给出提示信息
git_exists=0
if [ -d "${project_root_path}"/.git ]; then git_exists=1; fi
if (( "${git_exists}" == 0 )); then
    read -r -n 1 -p ".git was not found,do you want to continue? [y/N]" continue_yn
    echo
    case "${continue_yn}" in
        'y'|'Y')
            continue_yn=1
            ;;
        *)
            continue_yn=0
            ;;
    esac

    if (( "${continue_yn}" == 0 )); then exit 1; fi
fi

#找到所有脚本,并存入数组
scripts_array=()
#-t:strip newlines
#The first < is a redirection character. It expects to be followed by a file name, or file descriptor. The contents of that file are redirected to the standard input of the preceding command.
#These characters indicate process substitution, which returns a file descriptor. The commands inside the parentheses are executed, and their output is assigned to this file descriptor. In any bash command, you can use process substitution like a file name.
myself_name=$(basename "${0}")
mapfile -t scripts_array < <(find . -type f -not -path "./.git/*" -not -name "README*" -not -name "LICENSE" -not -name "${myself_name}")

#读取所有的脚本,收集所有的类别,存储数组,然后合并重复项,并且对数组排序
category_array=()
#读取每个脚本的类别,描述,以脚本的路径作为key来存储到关联数组中,在关联数组中每个value,其中第一行代表类别,其余行代表描述
declare -A scripts_info_array
for script in "${scripts_array[@]}"
do
    category=$(do_sed -n 's/#=//p' "${script}")
    description=$(do_sed -n 's/#@//p' "${script}")
    description=$(echo "${description}" | do_sed -n ':a;N;$!ba;s/\n/<br>/gp')

    category_array+=("${category}")

    #add $ operator before \n
    scripts_info_array["${script}"]="${category}"$'\n'"${description}"
done

#打印关联数组
#"${!scripts_info_array[@]}":获取关联数组的所有键
#for key in "${!scripts_info_array[@]}"; do
#    echo "${scripts_info_array[$key]}"
#done

#-u,--unique:unique keys
#把数组每个元素作为一行字符串,然后用sort来对行进行排列,并且单一化
unique_sorted_category_string=$(printf "%s\n" "${category_array[@]}" | sort -u)
#因为每个元素作为一行字符串,所以这里通过sed来读取,读取后去掉换行符,然后放入数组中
mapfile -t unique_sorted_category_array< <(echo "${unique_sorted_category_string}" | do_sed -n 'p')

#scripts_array这个数组里面存储的是脚本的名字,比如:"./script.sh",同时该脚本名字也是scripts_info_array这个关联数组的key,现在对scripts_array进行排序,然后遍历取出每一个key,然后用key再去取值,这样就实现了对每个类别下的脚本按行进行了排序
#-r:逆序,便于后面往README.md里面插入
sorted_reverse_scripts_string=$(printf "%s\n" "${scripts_array[@]}" | sort -n -r)
mapfile -t sorted_reverse_scripts_array< <(echo "${sorted_reverse_scripts_string}" | do_sed -n 'p')

#如果已经存在README.md文件,那么将其备份
if (( readme_already_exists == 1 )); then mv "${readme_path}"/"${readme_name}" "${readme_path}"/"${readme_name}".bak; fi

#生成新的README.md文件
#1,先插入类别,每行一个类别,行与行之间添加一个空行
for category in "${unique_sorted_category_array[@]}"
do
    { echo -n "## "; echo "${category}:"; } >> "${readme_name}"
done
#2,遍历sorted_reverse_scripts_array,该数组是经过排序的,使用该数组的元素作为key来从scripts_info_array这个关联数组中取出每个脚本文件的信息,然后添加到对应的类别下面,这样添加后,每个类别下的脚本文件也就是按顺序的
for script in "${sorted_reverse_scripts_array[@]}"
do
    value="${scripts_info_array["${script}"]}"

    #该脚本所属的类别是value的第一行,value剩余的行是该脚本的描述信息
    category=$(echo "${value}" | do_sed -n '1p')

    #脚本的路径
    script_path=$(echo "${script}" | do_sed -n 's|./||p')
    #脚本的名字
    script_basename=$(basename "${script_path}")
    script_link="### [$script_basename]($script_path):<br>"

    description=$(echo "${value}" | do_sed -n '2,$p')

    #在README.md中找到该脚本所属的类别,然后将该脚本的link信息和描述信息插入其后
    do_sed -i "/^## $category:$/r"<(
        echo "${script_link}"
        echo "${description}"
        echo
    ) "${readme_path}/${readme_name}"
done

#如果README.md文件,最后有一个空行的话,那么将其删掉
last_line=$(tail -n 1 "${readme_path}"/"${readme_name}")
if [[ "${last_line}" == '' ]]; then
    do_sed -i '$ d' "${readme_path}/${readme_name}"
fi

#如果已经存在README.md文件,那么给出二者的diff,并提示是否要删除备份
if (( readme_already_exists == 1 )); then
    diff --color=auto --unified "${readme_path}"/"${readme_name}".bak "${readme_path}"/"${readme_name}"

    read -r -n 1 -p "delete ${readme_path}/${readme_name}.bak? [Y/n]" delete_bak
    echo
    case "${delete_bak}" in
        'y'|'Y'|'')
            delete_bak=1
            ;;
        *)
            delete_bak=0
            ;;
    esac

    if (( "${delete_bak}" == 1 )); then rm "${readme_path}"/"${readme_name}".bak; fi
fi
