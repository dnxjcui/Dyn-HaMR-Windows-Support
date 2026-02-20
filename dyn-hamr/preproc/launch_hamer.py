import os
import subprocess
import multiprocessing as mp
from concurrent import futures

from preproc.datasets import update_args
from preproc.export_hamer import export_sequence_results

ROOT_DIR = os.path.abspath(f"{__file__}/../../../")
SRC_DIR = os.path.join(ROOT_DIR, "third-party", "hamer")

def launch_hamer(gpus, seq, img_dir, res_dir, name, datatype, overwrite=False):
    """
    run hamer using GPU pool
    """
    cur_proc = mp.current_process()
    print("PROCESS", cur_proc.name, cur_proc._identity)
    gpu = gpus[0]

    HAMER_DIR = SRC_DIR
    print("HAMER DIR", HAMER_DIR)

    # Set GPU via environment variable (cross-platform)
    env = os.environ.copy()
    env["CUDA_VISIBLE_DEVICES"] = str(gpu)

    cmd = [
        "python", "-u", "run.py",
        "--img_folder", img_dir,
        "--res_folder", os.path.join(res_dir, f"demo_{name}.pkl"),
        "--batch_size=48", "--side_view", "--save_mesh", "--full_frame",
        "--type", datatype,
        "--checkpoint", ROOT_DIR,
        "--render",
    ]

    print(f"Running HaMeR in {HAMER_DIR}: {' '.join(cmd)}")
    return subprocess.call(cmd, cwd=HAMER_DIR, env=env)


def process_seq(
    gpus,
    out_root,
    seq,
    img_dir,
    out_name="hamer_out",
    datatype=None,
    track_name="track_preds",
    shot_name="shot_idcs",
    overwrite=False,
):
    """
    Run and export HAMER results
    """
    name = os.path.basename(seq)
    res_root = os.path.join(out_root, out_name, seq)
    os.makedirs(res_root, exist_ok=True)
    res_dir = os.path.join(res_root, "results")
    res_path = os.path.join(res_root, f"{name}.pkl")

    if overwrite or not os.path.isfile(res_path):
        res = launch_hamer(gpus, seq, img_dir, res_dir, name, datatype, overwrite)
        assert res == 0, "HAMER FAILED"
        src_pkl = os.path.join(res_dir, f"demo_{name}.pkl")
        print(f'rename {src_pkl} into ', res_path)
        os.rename(src_pkl, res_path)

    # export the HAMER predictions
    track_dir = os.path.join(out_root, track_name, seq)
    shot_path = os.path.join(out_root, shot_name, f"{seq}.json")

    export_sequence_results(res_path, track_dir, shot_path)
    return 0


def get_out_dir(src_root, src_dir, src_token, out_token):
    """
    :param src_root (str) root of all data
    :param src_dir (str) img input dir
    :param src_token (str) parent name of image input dir
    :param out_token (str) name of output dir
    """
    src_suffix = src_dir.removeprefix(src_root)
    out_dir = f"{out_root}/{src_suffix}"
    return out_dir.replace(src_token, out_token)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--type", default="posetrack", help="dataset to process")
    parser.add_argument("--root", default=None, help="root dir of data, default None")
    parser.add_argument("--split", default="val", help="split of dataset, default val")
    parser.add_argument(
        "--img_name", default=None, help="input image directory name, default None"
    )
    parser.add_argument("--seqs", nargs="*", default=None)
    parser.add_argument("--gpus", nargs="*", default=[0])
    parser.add_argument("-y", "--overwrite", action="store_true")

    args = parser.parse_args()
    args = update_args(args)

    out_root = f"{args.root}/slahmr/{args.split}"

    print(f"running phalp on {len(args.img_dirs)} image directories")
    if len(args.gpus) > 1:
        with futures.ProcessPoolExecutor(max_workers=len(args.gpus)) as exe:
            for img_dir, seq in zip(args.img_dirs, args.seqs):
                exe.submit(
                    process_seq,
                    args.gpus,
                    out_root,
                    seq,
                    img_dir,
                    overwrite=args.overwrite,
                )
    else:
        for img_dir, seq in zip(args.img_dirs, args.seqs):
            process_seq(args.gpus, out_root, seq, img_dir, overwrite=args.overwrite)
