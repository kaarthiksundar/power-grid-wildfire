# parallel load factor 1.00 runs 
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 25
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 50
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 75
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 100
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 125
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 150
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 175
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ --parallel -s 200

# parallel load factor 1.05 runs 
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 25
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 50
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 75
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 100
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 125
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 150
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 175
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ --parallel -s 200

# serial load factor 1.00 runs 
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 25
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 50
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 75
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 100

# serial load factor 1.05 runs 
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 25
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 50
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 75
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 100