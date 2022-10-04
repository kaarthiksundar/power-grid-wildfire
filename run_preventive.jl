# parallel load factor 1.00 runs 
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 10
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 20
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 30
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 40
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 50
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 60
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 70
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 80
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 90
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 100

# parallel load factor 1.05 runs 
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 10
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 20
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 30
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 40
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 50
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 60
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 70
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 80
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 90
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 100

# serial runs 
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 10
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 20
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 30
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 10
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 20
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 30