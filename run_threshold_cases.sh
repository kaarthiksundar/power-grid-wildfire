julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 200
julia --project=. src/main.jl --model corrective --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 200
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.00 --result_folder ./output/ -s 200
julia --project=. src/main.jl --model preventive --switch_budget 5 --load_weighting_factor 1.05 --result_folder ./output/ -s 200